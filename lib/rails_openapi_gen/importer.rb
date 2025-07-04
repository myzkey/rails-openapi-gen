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
      @partial_schemas = {} # Store schemas for partials
      
      # First pass: collect all response schemas
      openapi_spec['paths']&.each do |path, methods|
        methods.each do |method, operation|
          next if method == 'parameters' # Skip path-level parameters
          
          response_schema = extract_response_schema(operation)
          if response_schema
            if response_schema['type'] == 'array' && response_schema['items']
              # For array responses, store the item schema
              item_schema = response_schema['items']
              if item_schema['properties']
                # Extract resource name from path dynamically
                resource_name = extract_resource_name_from_path(path)
                if resource_name
                  @partial_schemas[resource_name] ||= item_schema
                end
                collect_partial_schemas(item_schema['properties'])
              end
            elsif response_schema['properties']
              # For object responses
              collect_partial_schemas(response_schema['properties'])
              
              # Store the root schema if it's a detail endpoint
              if path.match?(/\{(id|\w+_id)\}$/)
                resource_name = extract_resource_name_from_path(path)
                if resource_name
                  @partial_schemas["#{resource_name}_detail"] = response_schema
                end
              end
            end
          end
        end
      end
      
      # Second pass: process files and add comments
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
      
      # Third pass: process partial files
      process_partial_files()
      
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
    
    def extract_resource_name_from_path(path)
      # Extract the resource name from OpenAPI path
      # Examples:
      # /posts -> posts
      # /users/{id} -> users
      # /users/{user_id}/posts -> posts
      # /posts/{post_id}/comments -> comments
      
      # Remove leading slash and split by '/'
      segments = path.sub(/^\//, '').split('/')
      
      # Find the last segment that doesn't contain parameters
      resource_segment = segments.reverse.find { |segment| !segment.include?('{') }
      
      # Return singular form if found
      resource_segment&.singularize
    end
    
    def collect_partial_schemas(properties, parent_key = nil)
      # Collect schemas that might be used in partials
      properties.each do |key, schema|
        if schema['type'] == 'object' && schema['properties']
          # Store schema for potential partial use
          @partial_schemas[key] = schema
          
          # Also store the full schema if it's from the root level
          # This helps with matching post/user objects at the top level
          if parent_key.nil? && (key == 'post' || key == 'posts' || key == 'user' || key == 'users')
            @partial_schemas["_#{key.singularize}"] = schema
          end
          
          # Recursively collect nested schemas
          collect_partial_schemas(schema['properties'], key)
        elsif schema['type'] == 'array' && schema['items'] && schema['items']['properties']
          @partial_schemas[key] = schema['items']
          @partial_schemas["_#{key.singularize}"] = schema['items']
          collect_partial_schemas(schema['items']['properties'], key)
        end
      end
    end
    
    def process_partial_files
      # Find and process partial files
      Dir.glob(Rails.root.join('app/views/**/_*.json.jbuilder')).each do |partial_path|
        next if @processed_files.include?(partial_path)
        
        # Try to match partial with collected schemas
        partial_name = File.basename(partial_path, '.json.jbuilder').sub(/^_/, '')
        
        # Look for matching schema based on partial name
        matching_schema = find_schema_for_partial(partial_name)
        next unless matching_schema
        
        if add_comments_to_partial(partial_path, matching_schema)
          @processed_files << partial_path
          puts "  📝 Updated partial: #{partial_path}"
        end
      end
    end
    
    def find_schema_for_partial(partial_name)
      # Try to find a schema that matches the partial name
      # Look for singular and plural forms
      
      # First, try direct name matching
      return @partial_schemas[partial_name] if @partial_schemas[partial_name]
      return @partial_schemas[partial_name.pluralize] if @partial_schemas[partial_name.pluralize]
      return @partial_schemas[partial_name.singularize] if @partial_schemas[partial_name.singularize]
      
      # Try to find common base properties across all schemas
      # This is a more generic approach that doesn't hardcode specific models
      base_schema = find_common_properties_schema(partial_name)
      return base_schema if base_schema
      
      # Fall back to property matching
      find_schema_by_properties(partial_name)
    end
    
    def find_common_properties_schema(partial_name)
      # Find schemas that might represent this partial
      # by looking for schemas with properties that match the partial content
      partial_path = Dir.glob(Rails.root.join("app/views/**/_{partial_name}.json.jbuilder")).first
      return nil unless partial_path && File.exist?(partial_path)
      
      # Parse the partial to get its properties
      partial_content = File.read(partial_path)
      partial_properties = partial_content.scan(/json\.(\w+)/).flatten.uniq
      
      # Find all schemas that could match
      candidate_schemas = []
      @partial_schemas.each do |key, schema|
        next unless schema['properties']
        
        # Calculate how many properties match
        matching_props = partial_properties & schema['properties'].keys
        if matching_props.size >= partial_properties.size * 0.5 # At least 50% match
          candidate_schemas << {
            schema: schema,
            match_count: matching_props.size,
            properties: schema['properties'].slice(*matching_props)
          }
        end
      end
      
      return nil if candidate_schemas.empty?
      
      # If we have multiple candidates, find common properties across all of them
      if candidate_schemas.size > 1
        common_properties = extract_common_properties(candidate_schemas)
        return { 'properties' => common_properties } if common_properties.any?
      end
      
      # Otherwise return the best matching schema
      best_match = candidate_schemas.max_by { |c| c[:match_count] }
      { 'properties' => best_match[:properties] }
    end
    
    def extract_common_properties(candidate_schemas)
      # Find properties that appear in all candidate schemas with the same type
      common_props = {}
      
      # Get all property names from the first schema
      first_schema_props = candidate_schemas.first[:schema]['properties']
      
      first_schema_props.each do |prop_name, prop_schema|
        # Check if this property exists in all candidates with the same type
        is_common = candidate_schemas.all? do |candidate|
          candidate[:schema]['properties'][prop_name] &&
          candidate[:schema]['properties'][prop_name]['type'] == prop_schema['type']
        end
        
        if is_common
          # Use the most detailed schema for this property
          # (the one with the most attributes like description, enum, etc.)
          most_detailed = candidate_schemas.map { |c| c[:schema]['properties'][prop_name] }
                                          .max_by { |p| p.keys.size }
          common_props[prop_name] = most_detailed
        end
      end
      
      common_props
    end
    
    def find_schema_by_properties(partial_name)
      # Try to match by analyzing the partial content
      # This is a more complex matching strategy
      partial_path = Dir.glob(Rails.root.join("app/views/**/_{partial_name}.json.jbuilder")).first
      return nil unless partial_path && File.exist?(partial_path)
      
      content = File.read(partial_path)
      property_names = content.scan(/json\.(\w+)/).flatten.uniq
      
      # Find schema that has most matching properties
      best_match = nil
      best_score = 0
      
      @partial_schemas.each do |key, schema|
        next unless schema['properties']
        
        matching_props = property_names & schema['properties'].keys
        score = matching_props.size.to_f / property_names.size
        
        if score > best_score && score > 0.5 # At least 50% match
          best_match = schema
          best_score = score
        end
      end
      
      best_match
    end
    
    def add_comments_to_partial(partial_path, schema)
      return false unless File.exist?(partial_path)
      
      content = File.read(partial_path)
      
      # Parse the partial file
      jbuilder_result = Parsers::JbuilderParser.new(partial_path).parse
      properties = jbuilder_result[:properties]
      
      # Generate new content with comments
      new_content = generate_commented_jbuilder(content, properties, schema, nil, nil)
      
      # Write back to file
      File.write(partial_path, new_content)
      
      true
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
      current_schema_stack = [response_schema]
      indent_stack = [0]
      in_block_stack = [] # Track if we're inside a do block
      
      # Add operation comment if needed at the very beginning
      if should_add_operation_comment(content, operation)
        new_lines << generate_operation_comment(operation)
        new_lines << "\n"
      end
      
      # Process each line
      lines.each_with_index do |line, index|
        current_indent = line.match(/^(\s*)/)[1].length
        
        # Check for block end
        if line.strip == 'end' && in_block_stack.any?
          in_block_stack.pop
          # Pop schema stack when exiting a block
          if indent_stack.last && current_indent <= indent_stack.last
            current_schema_stack.pop
            indent_stack.pop
          end
        end
        
        # Update schema stack based on indentation (for other cases)
        while indent_stack.last && current_indent < indent_stack.last && in_block_stack.empty?
          current_schema_stack.pop
          indent_stack.pop
        end
        
        # Check for json.array! patterns first (before general json property check)
        if line.strip.include?('json.array!')
          # Handle json.array! @posts do |post| patterns
          match = line.strip.match(/^json\.array!\s+@(\w+)\s+do\s+\|(\w+)\|/)
          if match
            collection_name = match[1]  # e.g., "posts"
            item_name = match[2]        # e.g., "post"
            
            # Add comment for the array itself if this is a root-level array
            if current_schema_stack.size == 1 && current_schema_stack.first&.dig('type') == 'array'
              unless has_openapi_comment?(lines, index)
                array_comment = "# @openapi root:array items:object"
                new_lines << (' ' * current_indent) + array_comment + "\n"
              end
            end
            
            # Look for array item schema - try response_schema['items'] first
            item_schema = current_schema_stack.last&.dig('items')
            # For root-level arrays, use the response schema items directly
            if !item_schema && current_schema_stack.size == 1 && current_schema_stack.first&.dig('type') == 'array'
              item_schema = current_schema_stack.first['items']
            end
            item_schema ||= @partial_schemas[item_name.singularize]
            
            if item_schema
              current_schema_stack << item_schema
              indent_stack << current_indent
              in_block_stack << true
            end
          end
        # Check for other array patterns like json.tags @post[:tags] do |tag|
        elsif line.strip.match(/^json\.(\w+)\s+.*do\s+\|(\w+)\|/)
          match = line.strip.match(/^json\.(\w+)\s+.*do\s+\|(\w+)\|/)
          if match
            property_name = match[1]  # e.g., "tags"
            item_name = match[2]      # e.g., "tag"
            
            # Look for this property in current schema
            current_schema = current_schema_stack.last
            if current_schema && current_schema['properties'] && current_schema['properties'][property_name]
              property_schema = current_schema['properties'][property_name]
              
              # Add comment for the array property itself if needed
              if !has_openapi_comment?(lines, index)
                comment = generate_property_comment(property_name, property_schema)
                new_lines << (' ' * current_indent) + comment + "\n" if comment
              end
              
              # If it's an array with items, push the items schema
              if property_schema['type'] == 'array' && property_schema['items'] && property_schema['items']['properties']
                current_schema_stack << property_schema['items']
                indent_stack << current_indent
                in_block_stack << true
              elsif property_schema['type'] == 'array' && property_schema['items']
                # Try to find schema by item name
                item_schema = @partial_schemas[item_name.singularize] || @partial_schemas[item_name]
                if item_schema
                  current_schema_stack << item_schema
                  indent_stack << current_indent
                  in_block_stack << true
                end
              end
            end
          end
        elsif line.strip.match(/^json\.partial!.*['"](\w+)\/_(\w+)['"]/) 
          # Handle partials - check if next line should have nested properties
          match = line.strip.match(/^json\.partial!.*['"](\w+)\/_(\w+)['"]/)
          if match
            partial_dir = match[1]
            partial_name = match[2]
            
            # Check if this is inside a block (like json.author do)
            if in_block_stack.any? && current_schema_stack.last
              # We're inside a block, current schema should have the right context
              current_schema = current_schema_stack.last
              # The partial will handle its own properties
            end
          end
        # Check if this line is a json property (general case)
        elsif json_property_line?(line)
          property_name = extract_property_name(line)
          
          if property_name
            current_schema = current_schema_stack.last
            
            if current_schema && current_schema['properties']
              property_schema = current_schema['properties'][property_name]
              
              if property_schema && !has_openapi_comment?(lines, index)
                # Add comment before this line
                comment = generate_property_comment(property_name, property_schema)
                new_lines << (' ' * current_indent) + comment + "\n" if comment
              end
              
              # Check if this line opens a block
              if line.include?(' do')
                in_block_stack << true
                if property_schema
                  # Push the nested schema onto the stack
                  if property_schema['type'] == 'object' && property_schema['properties']
                    current_schema_stack << property_schema
                    indent_stack << current_indent
                  elsif property_schema['type'] == 'array' && property_schema['items'] && property_schema['items']['properties']
                    current_schema_stack << property_schema['items']
                    indent_stack << current_indent
                  end
                end
              elsif line.include?(' do |') && property_schema && property_schema['type'] == 'array'
                # Array iteration block
                in_block_stack << true
                if property_schema['items'] && property_schema['items']['properties']
                  current_schema_stack << property_schema['items']
                  indent_stack << current_indent
                end
              end
            end
          end
        end
        
        new_lines << line
      end
      
      new_lines.join
    end

    def should_add_operation_comment(content, operation)
      # Check if operation comment already exists
      return false unless operation
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
      
      type = property_schema['type'] || 'string'
      parts = ["#{property_name}:#{type}"]
      
      # Handle array items type
      if type == 'array' && property_schema['items']
        items_type = property_schema['items']['type'] || 'string'
        parts[0] = "#{property_name}:array"
        parts << "items:#{items_type}"
      end
      
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