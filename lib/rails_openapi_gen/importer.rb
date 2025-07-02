# frozen_string_literal: true

require "yaml"
require "set"

module RailsOpenapiGen
  class Importer
    def initialize(openapi_file = nil)
      @openapi_file = openapi_file || File.join(RailsOpenapiGen.configuration.output_directory, 
                                               RailsOpenapiGen.configuration.output_filename)
      @routes_parser = Parsers::RoutesParser.new
      @processed_files = Set.new
    end

    def run
      unless File.exist?(@openapi_file)
        puts "❌ OpenAPI file not found: #{@openapi_file}"
        return
      end

      openapi_spec = YAML.load_file(@openapi_file)
      routes = @routes_parser.parse
      
      processed_count = 0
      
      openapi_spec['paths']&.each do |path, methods|
        methods.each do |method, operation|
          next if method == 'parameters' # Skip path-level parameters
          
          matching_route = find_matching_route(path, method.upcase, routes)
          next unless matching_route
          
          controller_info = Parsers::ControllerParser.new(matching_route).parse
          next unless controller_info[:jbuilder_path]
          
          if add_comments_to_jbuilder(controller_info, operation, matching_route)
            processed_count += 1
          end
        end
      end
      
      puts "✅ Updated #{processed_count} Jbuilder templates with OpenAPI comments"
    end

    private

    def find_matching_route(openapi_path, method, routes)
      # Convert OpenAPI path format {id} to Rails format :id
      rails_path = openapi_path.gsub(/\{(\w+)\}/, ':\1')
      
      routes.find do |route|
        route[:method] == method && normalize_path(route[:path]) == normalize_path(rails_path)
      end
    end

    def normalize_path(path)
      # Remove trailing slashes and normalize
      path.gsub(/\/$/, '')
    end

    def add_comments_to_jbuilder(controller_info, operation, route)
      jbuilder_path = controller_info[:jbuilder_path]
      return false unless File.exist?(jbuilder_path)
      return false if @processed_files.include?(jbuilder_path)
      
      @processed_files << jbuilder_path
      
      content = File.read(jbuilder_path)
      
      # Parse the Jbuilder file to understand its structure
      jbuilder_result = Parsers::JbuilderParser.new(jbuilder_path).parse
      properties = jbuilder_result[:properties]
      
      # Get the response schema from the operation
      response_schema = extract_response_schema(operation)
      return false unless response_schema
      
      # Generate new content with comments
      new_content = generate_commented_jbuilder(content, properties, response_schema, operation, route)
      
      # Write back to file
      File.write(jbuilder_path, new_content)
      
      puts "  📝 Updated: #{jbuilder_path}"
      true
    end

    def extract_response_schema(operation)
      # Look for 200 response first, then any other successful response
      responses = operation['responses'] || {}
      
      success_response = responses['200'] || responses['201'] || responses.values.first
      return nil unless success_response
      
      content = success_response['content'] || {}
      json_content = content['application/json'] || {}
      json_content['schema']
    end

    def generate_commented_jbuilder(content, properties, response_schema, operation, route)
      lines = content.lines
      new_lines = []
      
      # Add operation comment if needed
      if should_add_operation_comment(content, operation)
        new_lines << generate_operation_comment(operation)
        new_lines << ""
      end
      
      # Process each line
      lines.each_with_index do |line, index|
        # Check if this line is a json property
        if json_property_line?(line)
          property_name = extract_property_name(line)
          
          if property_name && response_schema && response_schema['properties']
            property_schema = response_schema['properties'][property_name]
            
            if property_schema && !has_openapi_comment?(lines, index)
              # Add comment before this line
              comment = generate_property_comment(property_name, property_schema)
              new_lines << comment if comment
            end
          end
        end
        
        new_lines << line
      end
      
      new_lines.join
    end

    def should_add_operation_comment(content, operation)
      # Check if operation comment already exists
      !content.include?('@openapi_operation') && 
        (operation['summary'] || operation['description'] || operation['tags'])
    end

    def generate_operation_comment(operation)
      parts = []
      parts << "summary:\"#{operation['summary']}\"" if operation['summary']
      parts << "description:\"#{operation['description']}\"" if operation['description']
      
      if operation['tags'] && operation['tags'].any?
        tags = operation['tags'].map { |tag| tag.to_s }.join(',')
        parts << "tags:[#{tags}]"
      end
      
      # Get status code (first response key)
      responses = operation['responses'] || {}
      status_code = responses.keys.first
      if status_code && status_code != '200'
        parts << "status:\"#{status_code}\""
      end
      
      
      return nil if parts.empty?
      
      "# @openapi_operation #{parts.join(' ')}"
    end

    def json_property_line?(line)
      line.strip.match?(/^json\.\w+/)
    end

    def extract_property_name(line)
      match = line.strip.match(/^json\.(\w+)/)
      match ? match[1] : nil
    end

    def has_openapi_comment?(lines, current_index)
      # Check the previous line for @openapi comment
      return false if current_index == 0
      
      prev_line = lines[current_index - 1].strip
      prev_line.include?('@openapi')
    end

    def generate_property_comment(property_name, property_schema)
      return nil unless property_schema
      
      parts = ["#{property_name}:#{property_schema['type'] || 'string'}"]
      
      if property_schema['required'] == false
        parts << "required:false"
      end
      
      if property_schema['description']
        parts << "description:\"#{property_schema['description']}\""
      end
      
      if property_schema['enum']
        enum_values = property_schema['enum'].map(&:to_s).join(',')
        parts << "enum:[#{enum_values}]"
      end
      
      if property_schema['format']
        parts << "format:#{property_schema['format']}"
      end
      
      if property_schema['minimum']
        parts << "minimum:#{property_schema['minimum']}"
      end
      
      if property_schema['maximum']
        parts << "maximum:#{property_schema['maximum']}"
      end
      
      "# @openapi #{parts.join(' ')}"
    end
  end
end