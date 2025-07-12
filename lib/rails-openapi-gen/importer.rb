# frozen_string_literal: true

require "yaml"
require "set"

module RailsOpenapiGen
  class Importer
    # Initializes importer with OpenAPI specification file
    # @param openapi_file [String, nil] Path to OpenAPI spec file (defaults to configured output)
    def initialize(openapi_file = nil)
      @openapi_file = openapi_file || File.join(
        RailsOpenapiGen.configuration.output_directory,
        RailsOpenapiGen.configuration.output_filename
      )
      @routes_parser = Parsers::RoutesParser.new
      @processed_files = Set.new
    end

    # Runs the import process to generate @openapi comments in Jbuilder files
    # @return [void]
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

    # Extracts properties from AST node for backward compatibility
    # @param ast_node [RailsOpenapiGen::AstNodes::BaseNode] AST node
    # @return [Array<Hash>] Properties in legacy format
    def extract_properties_from_ast(ast_node)
      properties = []
      
      if ast_node.respond_to?(:properties)
        ast_node.properties.each do |property|
          properties << {
            name: property.property_name,
            type: property.comment_data&.openapi_type || 'string',
            description: property.comment_data&.description,
            required: property.comment_data&.required != false
          }
        end
      end
      
      properties
    end

    # Finds Rails route matching OpenAPI path and method
    # @param openapi_path [String] OpenAPI path format (e.g., "/users/{id}")
    # @param method [String] HTTP method
    # @param routes [Array<Hash>] Array of Rails routes
    # @return [Hash, nil] Matching route or nil
    def find_matching_route(openapi_path, method, routes)
      # Convert OpenAPI path format {id} to Rails format :id
      rails_path = openapi_path.gsub(/\{(\w+)\}/, ':\1')

      routes.find do |route|
        route[:method] == method && normalize_path(route[:path]) == normalize_path(rails_path)
      end
    end

    # Normalizes path by removing trailing slashes
    # @param path [String] Path to normalize
    # @return [String] Normalized path
    def normalize_path(path)
      # Remove trailing slashes and normalize
      path.gsub(/\/$/, '')
    end

    # Extracts resource name from OpenAPI path
    # @param path [String] OpenAPI path (e.g., "/users/{id}/posts")
    # @return [String, nil] Singular resource name or nil
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

    # Collects schemas that might be used in partials
    # @param properties [Hash] Properties hash from schema
    # @param parent_key [String, nil] Parent property key for nested objects
    # @return [void]
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

    # Processes partial files to add OpenAPI comments
    # @return [void]
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

    # Finds appropriate schema for a partial template
    # @param partial_name [String] Name of the partial (e.g., "user")
    # @return [Hash, nil] Schema for the partial or nil
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

    # Finds schema with common properties for partial
    # @param partial_name [String] Name of the partial
    # @return [Hash, nil] Schema with common properties or nil
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

    # Extracts common properties from multiple schemas
    # @param candidate_schemas [Array<Hash>] Array of candidate schemas
    # @return [Hash] Schema with common properties
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

    # Finds schema by matching property names in partial
    # @param partial_name [String] Name of the partial
    # @return [Hash, nil] Matching schema or nil
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

    # Adds OpenAPI comments to a partial file
    # @param partial_path [String] Path to partial file
    # @param schema [Hash] Schema to use for comments
    # @return [void]
    def add_comments_to_partial(partial_path, schema)
      return false unless File.exist?(partial_path)

      content = File.read(partial_path)

      # Parse the partial file using new AST approach
      jbuilder_parser = Parsers::JbuilderParser.new(partial_path)
      ast_node = jbuilder_parser.parse_ast
      # Convert AST to properties for backward compatibility
      properties = ast_node ? extract_properties_from_ast(ast_node) : []

      # Generate new content with comments
      new_content = generate_commented_jbuilder(content, properties, schema, nil, nil)

      # Write back to file
      File.write(partial_path, new_content)

      true
    end

    # Adds OpenAPI comments to Jbuilder template
    # @param controller_info [Hash] Controller information including jbuilder_path
    # @param operation [Hash] OpenAPI operation data
    # @param route [Hash] Route information
    # @return [Boolean] True if file was updated
    def add_comments_to_jbuilder(controller_info, operation, route)
      jbuilder_path = controller_info[:jbuilder_path]
      return false unless File.exist?(jbuilder_path)
      return false if @processed_files.include?(jbuilder_path)

      @processed_files << jbuilder_path

      content = File.read(jbuilder_path)

      # Parse the Jbuilder file to understand its structure using new AST approach
      jbuilder_parser = Parsers::JbuilderParser.new(jbuilder_path)
      ast_node = jbuilder_parser.parse_ast
      # Convert AST to properties for backward compatibility
      properties = ast_node ? extract_properties_from_ast(ast_node) : []

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

    # Extracts response schema from OpenAPI operation
    # @param operation [Hash] OpenAPI operation data
    # @return [Hash, nil] Response schema or nil
    def extract_response_schema(operation)
      # Look for 200 response first, then any other successful response
      responses = operation['responses'] || {}

      success_response = responses['200'] || responses['201'] || responses.values.first
      return nil unless success_response

      content = success_response['content'] || {}
      json_content = content['application/json'] || {}
      json_content['schema']
    end

    # Generates Jbuilder content with OpenAPI comments
    # @param content [String] Original file content
    # @param properties [Array<Hash>] Parsed properties from Jbuilder
    # @param response_schema [Hash] Response schema from OpenAPI
    # @param operation [Hash, nil] OpenAPI operation data
    # @param route [Hash, nil] Route information
    # @return [String] Updated content with comments
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
            if current_schema && current_schema['properties']
              property_schema = find_property_in_schema(current_schema['properties'], property_name)

              # Add comment for the array property itself if needed
              if property_schema && !has_openapi_comment?(lines, index)
                comment = generate_property_comment(property_name, property_schema)
                new_lines << (' ' * current_indent) + comment + "\n" if comment
              end

              # If it's an array with items, push the items schema
              if property_schema && property_schema['type'] == 'array' && property_schema['items'] && property_schema['items']['properties']
                current_schema_stack << property_schema['items']
                indent_stack << current_indent
                in_block_stack << true
              elif property_schema && property_schema['type'] == 'array' && property_schema['items']
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
              property_schema = find_property_in_schema(current_schema['properties'], property_name)

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

    # Checks if operation comment should be added
    # @param content [String] File content
    # @param operation [Hash, nil] OpenAPI operation data
    # @return [Boolean] True if operation comment should be added
    def should_add_operation_comment(content, operation)
      # Check if operation comment already exists
      return false unless operation
      !content.include?('@openapi_operation') &&
        (operation['summary'] || operation['description'] || operation['tags'])
    end

    # Generates operation comment from OpenAPI data
    # @param operation [Hash] OpenAPI operation data
    # @return [String] Operation comment string
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

    # Checks if line contains a JSON property assignment
    # @param line [String] Line to check
    # @return [Boolean] True if JSON property line
    def json_property_line?(line)
      line.strip.match?(/^json\.\w+/)
    end

    # Extracts property name from JSON assignment line
    # @param line [String] Line containing JSON property
    # @return [String, nil] Property name or nil
    def extract_property_name(line)
      match = line.strip.match(/^json\.(\w+)/)
      match ? match[1] : nil
    end

    # Checks if line already has an OpenAPI comment
    # @param lines [Array<String>] All lines in the file
    # @param current_index [Integer] Current line index
    # @return [Boolean] True if OpenAPI comment exists
    def has_openapi_comment?(lines, current_index)
      # Check the previous line for @openapi comment
      return false if current_index == 0

      prev_line = lines[current_index - 1].strip
      prev_line.include?('@openapi')
    end

    # Finds property in schema using exact match only
    # @param properties [Hash] Properties hash from schema
    # @param property_name [String] Property name from jbuilder
    # @return [Hash, nil] Property schema or nil
    def find_property_in_schema(properties, property_name)
      properties[property_name]
    end

    # Generates property comment from schema
    # @param property_name [String] Name of the property
    # @param property_schema [Hash] Property schema from OpenAPI
    # @return [String] Generated comment string
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