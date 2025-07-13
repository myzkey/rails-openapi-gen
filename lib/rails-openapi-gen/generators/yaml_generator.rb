# frozen_string_literal: true

require "yaml"
require "fileutils"
require_relative "../processors/component_schema_processor"

module RailsOpenapiGen
  module Generators
    class YamlGenerator
      attr_reader :schemas, :components

      # Initializes YAML generator with schemas data
      # @param schemas [Hash] Hash of route information and schemas
      # @param components [Hash] Hash of component schemas from partials
      def initialize(schemas, components: {})
        @schemas = schemas
        @components = components
        @config = RailsOpenapiGen.configuration
        @base_path = @config.output_directory
      end

      # Generates OpenAPI YAML files from schemas
      # @return [void]
      def generate
        setup_directories

        paths_data = {}

        @schemas.each do |route, data|
          next if data.nil? || data[:schema].nil? || should_skip_schema?(data[:schema])

          path_key = normalize_path(route[:path])
          method = route[:method].downcase

          paths_data[path_key] ||= {}
          paths_data[path_key][method] = build_operation(route, data[:schema], data[:parameters], data[:operation])
        end

        if @config.split_files?
          write_endpoint_files(paths_data)
          write_component_files if @components && @components.any?
          write_main_openapi_file
        else
          write_single_file(paths_data)
        end
      end

      private

      # Checks if a schema should be skipped based on validity
      # @param schema [Hash] Schema to check
      # @return [Boolean] True if schema should be skipped
      def should_skip_schema?(schema)
        return true if schema.nil?

        # For object schemas, check if properties exist and are not empty
        if schema["type"] == "object"
          return schema["properties"].nil? || schema["properties"].empty?
        end

        # For array schemas, check if items are properly defined
        if schema["type"] == "array"
          return schema["items"].nil?
        end

        # For other types, don't skip
        false
      end

      # Creates necessary output directories and cleans existing path files
      # @return [void]
      def setup_directories
        FileUtils.mkdir_p(@base_path)
        if @config.split_files?
          paths_dir = File.join(@base_path, "paths")
          FileUtils.mkdir_p(paths_dir)
          # Clean existing path files to prevent merging with stale data
          clean_paths_directory(paths_dir)

          # Create components directory for partial components
          if @components && @components.any?
            components_dir = File.join(@base_path, "components", "schemas")
            FileUtils.mkdir_p(components_dir)
            clean_components_directory(components_dir)
          end
        end
      end

      # Cleans existing YAML files from the paths directory
      # @param paths_dir [String] Path to the paths directory
      # @return [void]
      def clean_paths_directory(paths_dir)
        Dir[File.join(paths_dir, "*.yaml")].each do |file|
          File.delete(file)
          puts "🗑️  Removed existing path file: #{File.basename(file)}" if ENV['RAILS_OPENAPI_DEBUG']
        end
      end

      # Cleans existing YAML files from the components directory
      # @param components_dir [String] Path to the components directory
      # @return [void]
      def clean_components_directory(components_dir)
        Dir[File.join(components_dir, "*.yaml")].each do |file|
          File.delete(file)
          puts "🗑️  Removed existing component file: #{File.basename(file)}" if ENV['RAILS_OPENAPI_DEBUG']
        end
      end

      # Converts Rails path format to OpenAPI format and removes API prefix if configured
      # @param path [String] Rails path (e.g., "/api/v1/users/:id")
      # @return [String] OpenAPI path (e.g., "/users/{id}")
      def normalize_path(path)
        # First remove API prefix if configured
        path_without_prefix = @config.remove_api_prefix(path)

        # Then convert Rails path parameters to OpenAPI format
        path_without_prefix.gsub(/:(\w+)/, '{\\1}')
      end

      # Builds OpenAPI operation object for a route
      # @param route [Hash] Route information
      # @param schema [Hash] Response schema
      # @param parameters [Hash] Request parameters
      # @param operation_info [Hash, nil] Operation metadata from comments
      # @return [Hash] OpenAPI operation object
      def build_operation(route, schema, parameters = {}, operation_info = nil)
        # Generate operationId with prefix removal
        default_operation_id = generate_operation_id(route)

        operation = {
          "summary" => operation_info&.dig(:summary) || "#{humanize(route[:action])} #{humanize(singularize(route[:controller]))}",
          "operationId" => operation_info&.dig(:operationId) || default_operation_id,
          "tags" => operation_info&.dig(:tags) || generate_tag_names(route)
        }

        # Add description if provided
        operation["description"] = operation_info[:description] if operation_info&.dig(:description)

        # Add parameters if they exist
        openapi_parameters = build_parameters(route, parameters)
        operation["parameters"] = openapi_parameters unless openapi_parameters.empty?

        # Add request body if body parameters exist
        request_body = build_request_body(parameters)
        operation["requestBody"] = request_body if request_body

        # Add responses with configurable status code
        status_code = operation_info&.dig(:status) || "200"
        response_description = "Successful response"

        operation["responses"] = {
          status_code => {
            "description" => response_description,
            "content" => {
              "application/json" => {
                "schema" => schema
              }
            }
          }
        }

        operation
      end

      # Writes path data to separate YAML files for each endpoint
      # @param paths_data [Hash] OpenAPI paths data
      # @return [void]
      def write_endpoint_files(paths_data)
        paths_data.each do |path, operations|
          endpoint_name = generate_endpoint_filename(path)
          file_data = { path => operations }

          file_path = File.join(@base_path, "paths", "#{endpoint_name}.yaml")
          File.write(file_path, file_data.to_yaml)

          puts "📝 Written endpoint file: #{endpoint_name}.yaml" if ENV['RAILS_OPENAPI_DEBUG']
        end
      end

      # Writes main OpenAPI specification file
      # @return [void]
      def write_main_openapi_file
        config = RailsOpenapiGen.configuration

        openapi_data = {
          "openapi" => config.openapi_version,
          "info" => deep_stringify_keys(config.info),
          "servers" => config.servers.map { |server| deep_stringify_keys(server) },
          "paths" => {}
        }

        Dir[File.join(@base_path, "paths", "*.yaml")].each do |path_file|
          paths = YAML.load_file(path_file)
          paths.each do |path, operations|
            openapi_data["paths"][path] = operations
          end
        end

        # Add components section with external references if we have any components
        if @components && @components.any?
          openapi_data["components"] = generate_components_references
        end

        File.write(File.join(@base_path, @config.output_filename), openapi_data.to_yaml)
      end

      # Writes all OpenAPI data to a single file
      # @param paths_data [Hash] OpenAPI paths data
      # @return [void]
      def write_single_file(paths_data)
        config = RailsOpenapiGen.configuration

        openapi_data = {
          "openapi" => config.openapi_version,
          "info" => deep_stringify_keys(config.info),
          "servers" => config.servers.map { |server| deep_stringify_keys(server) },
          "paths" => paths_data
        }

        File.write(File.join(@base_path, @config.output_filename), openapi_data.to_yaml)
      end

      # Recursively converts hash keys to strings
      # @param obj [Object] Object to process
      # @return [Object] Object with stringified keys
      def deep_stringify_keys(obj)
        case obj
        when Hash
          obj.transform_keys(&:to_s).transform_values { |v| deep_stringify_keys(v) }
        when Array
          obj.map { |v| deep_stringify_keys(v) }
        else
          obj
        end
      end

      # Generates filename for endpoint-specific files
      # @param path [String] API path (e.g., "/api/users/{id}")
      # @return [String] Filename (e.g., "api_users_id")
      def generate_endpoint_filename(path)
        # Remove leading slash and replace special characters
        clean_path = path.sub(%r{^/+}, '')
                         .gsub('/', '_')
                         .gsub(/[{}]/, '')
                         .gsub(/[^a-zA-Z0-9_]/, '_')
                         .gsub(/_+/, '_')
                         .gsub(/^_|_$/, '')

        clean_path.empty? ? 'root' : clean_path
      end

      # Converts snake_case string to human readable format
      # @param string [String] String to humanize
      # @return [String] Humanized string
      def humanize(string)
        string.to_s.gsub('_', ' ').split.map(&:capitalize).join(' ')
      end

      # Simple singularization of a string
      # @param string [String] String to singularize
      # @return [String] Singularized string
      def singularize(string)
        # Simple singularization - remove trailing 's' if present
        str = string.to_s
        str.end_with?('s') ? str[0..-2] : str
      end

      # Convert PascalCase/camelCase string to kebab-case with optional prefix removal
      # @param string [String] String to convert
      # @return [String] kebab-case string
      def to_kebab_case(string)
        # First remove component prefix if configured
        name_without_prefix = @config.remove_component_prefix(string.to_s)

        name_without_prefix.gsub(/([a-z\d])([A-Z])/, '\1-\2') # Insert dash before capital letters
                           .downcase # Convert to lowercase
      end

      # Convert PascalCase/camelCase string to snake_case
      # @param string [String] String to convert
      # @return [String] snake_case string
      def to_snake_case(string)
        string.to_s
              .gsub(/([a-z\d])([A-Z])/, '\1_\2') # Insert underscore before capital letters
              .downcase # Convert to lowercase
      end

      # Generate operationId with prefix removal from controller path
      # @param route [Hash] Route information
      # @return [String] Operation ID with prefix removed
      def generate_operation_id(route)
        controller_path = route[:controller]
        action = route[:action]

        # Remove API prefix from controller path if configured
        controller_without_prefix = remove_controller_prefix(controller_path)

        # Convert to underscore format for operationId
        "#{controller_without_prefix.gsub('/', '_')}_#{action}"
      end

      # Remove API prefix from controller path
      # @param controller_path [String] Controller path (e.g., "api/v1/users")
      # @return [String] Controller path with prefix removed (e.g., "users")
      def remove_controller_prefix(controller_path)
        # Use the same API prefix configuration
        api_prefix = @config.view_paths&.dig(:api_prefix)
        return controller_path unless api_prefix

        # Convert api_prefix to controller format (e.g., "api/v1" -> "api/v1")
        normalized_prefix = api_prefix.gsub(%r{^/+|/+$}, '') # Remove leading/trailing slashes

        # Remove the prefix if the controller path starts with it
        if controller_path.start_with?(normalized_prefix + '/')
          remaining_path = controller_path[(normalized_prefix.length + 1)..-1]
          remaining_path.empty? ? controller_path : remaining_path
        elsif controller_path == normalized_prefix
          # If controller path is exactly the prefix, return empty or fallback
          'root'
        else
          controller_path
        end
      end

      # Generate multiple tags based on URL path and controller path
      # @param route [Hash] Route information
      # @return [Array<String>] Array of tag names for the resources
      def generate_tag_names(route)
        controller_path = route[:controller]
        url_path = route[:path]

        # Remove API prefix from controller path
        controller_without_prefix = remove_controller_prefix(controller_path)

        # Also extract resource names from URL path for nested routes
        url_without_prefix = @config.remove_api_prefix(url_path)

        tags = []

        # Extract tags from controller path
        controller_parts = controller_without_prefix.split('/')
        controller_parts.each do |part|
          next if part.empty?

          tag = to_snake_case(part)
          tags << tag unless tags.include?(tag)
        end

        # Extract additional tags from URL path for nested resources
        # Match patterns like /users/{id}/posts to extract "users"
        url_segments = url_without_prefix.split('/').reject(&:empty?)

        url_segments.each do |segment|
          # Skip parameter segments like {id} or :id
          next if segment.match(/^[:{].*[}]?$/)

          # Convert to snake_case for consistency
          tag = segment.downcase.gsub('-', '_')
          tags << tag unless tags.include?(tag)
        end

        # Ensure we always have at least one tag
        tags.empty? ? ["Api"] : tags.uniq
      end

      # Builds OpenAPI parameter objects from route and parameter data
      # @param route [Hash] Route information
      # @param parameters [Hash] Parameter definitions
      # @return [Array<Hash>] Array of OpenAPI parameter objects
      def build_parameters(route, parameters)
        openapi_params = []

        # Add path parameters from route
        path_vars = route[:path].scan(/:(\w+)/).flatten
        path_vars.each do |path_var|
          # Look for matching parameter definition
          path_param = parameters[:path_parameters]&.find { |p| p[:name] == path_var }

          param = {
            "name" => path_var,
            "in" => "path",
            "required" => true,
            "schema" => {
              "type" => path_param&.dig(:type) || "string"
            }
          }
          param["description"] = path_param[:description] if path_param&.dig(:description)
          openapi_params << param
        end

        # Add query parameters
        parameters[:query_parameters]&.each do |query_param|
          param = {
            "name" => query_param[:name],
            "in" => "query",
            "required" => query_param[:required] != "false",
            "schema" => build_parameter_schema(query_param)
          }
          param["description"] = query_param[:description] if query_param[:description]
          openapi_params << param
        end

        openapi_params
      end

      # Builds OpenAPI request body object from body parameters
      # @param parameters [Hash] Parameter definitions
      # @return [Hash, nil] OpenAPI request body object or nil
      def build_request_body(parameters)
        return nil if parameters[:body_parameters].nil? || parameters[:body_parameters].empty?

        properties = {}
        required = []

        parameters[:body_parameters].each do |body_param|
          properties[body_param[:name]] = build_parameter_schema(body_param)
          required << body_param[:name] if body_param[:required] != "false"
        end

        {
          "required" => true,
          "content" => {
            "application/json" => {
              "schema" => {
                "type" => "object",
                "properties" => properties,
                "required" => required
              }
            }
          }
        }
      end

      # Builds parameter schema from parameter definition
      # @param param [Hash] Parameter definition
      # @return [Hash] OpenAPI parameter schema
      def build_parameter_schema(param)
        schema = { "type" => param[:type] || "string" }

        schema["description"] = param[:description] if param[:description]
        schema["enum"] = param[:enum] if param[:enum]
        schema["format"] = param[:format] if param[:format]
        schema["minimum"] = param[:minimum] if param[:minimum]
        schema["maximum"] = param[:maximum] if param[:maximum]
        schema["example"] = param[:example] if param[:example]

        schema
      end

      # Generate components section from collected partial components
      # @return [Hash] Components section for OpenAPI spec
      def generate_components_section
        return {} if @components.empty?

        components = {
          "schemas" => {}
        }

        @components.each do |component_name, ast_node|
          puts "📦 Generating component schema for: #{component_name}" if ENV['RAILS_OPENAPI_DEBUG']

          # Convert AST node to OpenAPI schema
          schema = Processors::AstToSchemaProcessor.new.process_to_schema(ast_node)
          components["schemas"][component_name] = schema
        end

        components
      end

      # Generate components section with external file references
      # @return [Hash] Components section with $ref to external files
      def generate_components_references
        return {} if @components.empty?

        components = {
          "schemas" => {}
        }

        @components.each_key do |component_name|
          # Remove prefix from both schema name and file name
          schema_name_without_prefix = @config.remove_component_prefix(component_name)
          kebab_filename = to_kebab_case(component_name)

          puts "🔗 Creating reference for component: #{component_name} -> #{schema_name_without_prefix} (#{kebab_filename}.yaml)" if ENV['RAILS_OPENAPI_DEBUG']

          # Create $ref to external component file (using kebab-case filename)
          # Use schema name without prefix as the key
          components["schemas"][schema_name_without_prefix] = {
            "$ref" => "./components/schemas/#{kebab_filename}.yaml"
          }
        end

        components
      end

      # Write individual component files to components/schemas directory
      # @return [void]
      def write_component_files
        return unless @components && @components.any?

        @components.each do |component_name, ast_node|
          kebab_filename = to_kebab_case(component_name)
          puts "📝 Writing component file: #{kebab_filename}.yaml" if ENV['RAILS_OPENAPI_DEBUG']

          # Convert AST node to OpenAPI schema (with inline expansion for components)
          schema = Processors::ComponentSchemaProcessor.new.process_to_schema(ast_node)

          # Write to individual YAML file
          file_path = File.join(@base_path, "components", "schemas", "#{kebab_filename}.yaml")
          File.write(file_path, schema.to_yaml)

          puts "✅ Component file written: #{kebab_filename}.yaml" if ENV['RAILS_OPENAPI_DEBUG']
        end
      end
    end
  end
end
