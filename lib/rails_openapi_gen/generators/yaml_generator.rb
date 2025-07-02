# frozen_string_literal: true

require "yaml"
require "fileutils"

module RailsOpenapiGen
  module Generators
    class YamlGenerator
      attr_reader :schemas

      def initialize(schemas)
        @schemas = schemas
        @config = RailsOpenapiGen.configuration
        @base_path = @config.output_directory
      end

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
          write_paths_files(paths_data)
          write_main_openapi_file
        else
          write_single_file(paths_data)
        end
      end

      private

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

      def setup_directories
        FileUtils.mkdir_p(@base_path)
        if @config.split_files?
          FileUtils.mkdir_p(File.join(@base_path, "paths"))
        end
      end

      def normalize_path(path)
        path.gsub(/:(\w+)/, '{\\1}')
      end

      def build_operation(route, schema, parameters = {}, operation_info = nil)
        operation = {
          "summary" => operation_info&.dig(:summary) || "#{humanize(route[:action])} #{humanize(singularize(route[:controller]))}",
          "operationId" => operation_info&.dig(:operationId) || "#{route[:controller].gsub('/', '_')}_#{route[:action]}",
          "tags" => operation_info&.dig(:tags) || [humanize(route[:controller].split('/').first)]
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

      def write_paths_files(paths_data)
        grouped_paths = paths_data.group_by { |path, _| extract_resource_name(path) }
        
        grouped_paths.each do |resource, paths|
          file_data = {}
          paths.each { |path, operations| file_data[path] = operations }
          
          file_path = File.join(@base_path, "paths", "#{resource}.yaml")
          File.write(file_path, file_data.to_yaml)
        end
      end

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
        
        File.write(File.join(@base_path, @config.output_filename), openapi_data.to_yaml)
      end

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

      def extract_resource_name(path)
        parts = path.split('/')
        return "root" if parts.empty? || parts.all?(&:empty?)
        
        parts.reject { |p| p.empty? || p.start_with?('{') }.first || "root"
      end

      def humanize(string)
        string.to_s.gsub('_', ' ').split.map(&:capitalize).join(' ')
      end

      def singularize(string)
        # Simple singularization - remove trailing 's' if present
        str = string.to_s
        str.end_with?('s') ? str[0..-2] : str
      end

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
    end
  end
end