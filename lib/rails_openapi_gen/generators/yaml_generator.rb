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
        
        @schemas.each do |route, schema|
          next if schema.nil? || schema["properties"].nil? || schema["properties"].empty?
          
          path_key = normalize_path(route[:path])
          method = route[:method].downcase
          
          paths_data[path_key] ||= {}
          paths_data[path_key][method] = build_operation(route, schema)
        end
        
        if @config.split_files?
          write_paths_files(paths_data)
          write_main_openapi_file
        else
          write_single_file(paths_data)
        end
      end

      private

      def setup_directories
        FileUtils.mkdir_p(@base_path)
        if @config.split_files?
          FileUtils.mkdir_p(File.join(@base_path, "paths"))
        end
      end

      def normalize_path(path)
        path.gsub(/:(\w+)/, '{\\1}')
      end

      def build_operation(route, schema)
        {
          "summary" => "#{humanize(route[:action])} #{humanize(singularize(route[:controller]))}",
          "operationId" => "#{route[:controller].gsub('/', '_')}_#{route[:action]}",
          "tags" => [humanize(route[:controller].split('/').first)],
          "responses" => {
            "200" => {
              "description" => "Successful response",
              "content" => {
                "application/json" => {
                  "schema" => schema
                }
              }
            }
          }
        }
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
    end
  end
end