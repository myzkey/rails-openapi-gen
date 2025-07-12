# frozen_string_literal: true

require 'rails-openapi-gen/version'
require 'rails-openapi-gen/configuration'
require 'pp'

# Zeitwerk autoloading setup
module RailsOpenapiGen
  autoload :AstNodes, "rails-openapi-gen/ast_nodes"
  autoload :Parsers, "rails-openapi-gen/parsers"
  autoload :Processors, "rails-openapi-gen/processors"
  autoload :Generators, "rails-openapi-gen/generators"
  autoload :Importer, "rails-openapi-gen/importer"
end

# Direct requires for core components that don't follow autoload patterns
require 'rails-openapi-gen/generators/yaml_generator'

# Rails integration is handled by Engine
if defined?(Rails::Engine)
  require 'rails-openapi-gen/engine'
end

module RailsOpenapiGen
  class Error < StandardError; end

  class << self
    # Generates OpenAPI specification from Rails application
    # @return [void]
    def generate
      Generator.new.run
    end

    # Checks for missing OpenAPI comments and uncommitted changes
    # @return [void]
    def check
      Checker.new.run
    end

    # Imports OpenAPI specification and generates @openapi comments in Jbuilder files
    # @param openapi_file [String, nil] Path to OpenAPI specification file (defaults to openapi/openapi.yaml)
    # @return [void]
    def import(openapi_file = nil)
      Importer.new(openapi_file).run
    end
  end

  class Checker
    # Checks for missing OpenAPI comments and uncommitted changes
    # @return [void]
    def run
      puts "🔍 Checking for missing comments and uncommitted changes..."
      
      # Run OpenAPI generation to check for missing comments
      system('bin/rails openapi:generate') || system('bundle exec rails openapi:generate')
      
      # Check for uncommitted changes in openapi directory
      if system('git diff --quiet docs/api/ 2>/dev/null')
        puts "✅ All checks passed!"
      else
        puts "❌ Found uncommitted changes in OpenAPI files"
        puts `git diff docs/api/`
        exit 1
      end
    end
  end

  class Generator
    # Runs the OpenAPI generation process
    # @return [void]
    def run
      # Load configuration
      RailsOpenapiGen.configuration.load_from_file

      routes = Parsers::RoutesParser.new.parse

      # Debug: Show filtering configuration
      config = RailsOpenapiGen.configuration

      # Apply filtering with debug output
      filtered_routes = routes.select do |route|
        included = config.route_included?(route[:path])
        included
      end

      schemas = {}

      filtered_routes.each do |route|
        begin
          controller_info = Parsers::ControllerParser.new(route).parse

          next unless controller_info[:jbuilder_path]

          jbuilder_parser = Parsers::Jbuilder::JbuilderParser.new(controller_info[:jbuilder_path])
          ast_node = jbuilder_parser.parse_ast
          schema = Processors::AstToSchemaProcessor.new.process_to_schema(ast_node)
          schemas[route] = {
            schema: schema,
            parameters: controller_info[:parameters] || {},
            operation: {} # Operation data is not available in AST approach
          }
        rescue => e
          puts "❌ ERROR processing route #{route[:method]} #{route[:path]}: #{e.class} - #{e.message}" if ENV['RAILS_OPENAPI_DEBUG']
          puts "❌ ERROR at: #{e.backtrace.first(3).join("\n")}" if ENV['RAILS_OPENAPI_DEBUG']
          raise
        end
      end

      Generators::YamlGenerator.new(schemas).generate
      puts '✅ OpenAPI specification generated successfully!'
    end

    private

    # Builds OpenAPI schema from AST properties array
    # @param properties [Array<Hash>] Array of property hashes with property name and comment_data
    # @return [Hash] OpenAPI schema object
    def build_schema(properties)
      schema = {
        "type" => "object",
        "properties" => {},
        "required" => []
      }

      properties.each do |prop|
        property_name = prop[:property] || prop["property"]
        comment_data = prop[:comment_data] || prop["comment_data"]
        is_conditional = prop[:is_conditional] || prop["is_conditional"]
        
        next unless property_name

        if comment_data
          property_schema = build_property_schema(prop)
          schema["properties"][property_name] = property_schema
          
          # Add to required unless explicitly marked as not required OR is conditional
          required = comment_data[:required] || comment_data["required"]
          unless required == false || required == "false" || is_conditional
            schema["required"] << property_name
          end
        else
          # Handle missing comments
          schema["properties"][property_name] = {
            "type" => "string",
            "description" => "TODO: MISSING COMMENT"
          }
          # Don't add conditional properties to required even if they have missing comments
          unless is_conditional
            schema["required"] << property_name
          end
        end
      end

      schema
    end

    # Builds property schema for a single property
    # @param prop [Hash] Property hash with comment_data and nested properties
    # @return [Hash] Property schema
    def build_property_schema(prop)
      comment_data = prop[:comment_data] || prop["comment_data"]
      property_type = comment_data[:type] || comment_data["type"] || "string"
      
      property_schema = {
        "type" => property_type
      }
      
      # Add description if present
      if comment_data[:description] || comment_data["description"]
        property_schema["description"] = comment_data[:description] || comment_data["description"]
      end
      
      # Add enum if present
      if comment_data[:enum] || comment_data["enum"]
        property_schema["enum"] = comment_data[:enum] || comment_data["enum"]
      end
      
      # Handle nested object properties
      if property_type == "object" && (prop[:nested_properties] || prop["nested_properties"])
        nested_properties = prop[:nested_properties] || prop["nested_properties"]
        nested_schema = build_schema(nested_properties)
        property_schema["properties"] = nested_schema["properties"]
        
        # Only add required array if there are non-conditional required properties
        if nested_schema["required"] && !nested_schema["required"].empty?
          property_schema["required"] = nested_schema["required"]
        end
      end
      
      property_schema
    end

    # Builds array schema from properties containing array root
    # @param properties [Array<Hash>] Array of property hashes
    # @return [Hash] Array schema object
    def build_array_schema(properties)
      array_root = properties.find { |p| p[:is_array_root] || p["is_array_root"] }
      
      unless array_root
        raise ArgumentError, "No array root property found in properties"
      end
      
      schema = {
        "type" => "array"
      }
      
      # Build items schema from array_item_properties
      array_item_properties = array_root[:array_item_properties] || array_root["array_item_properties"]
      if array_item_properties && !array_item_properties.empty?
        items_schema = build_schema(array_item_properties)
        schema["items"] = items_schema
      else
        schema["items"] = { "type" => "object" }
      end
      
      schema
    end

    # Note: Old hash-based processing methods have been removed
    # The system now uses AST-based processing with AstToSchemaProcessor
  end
end
