# frozen_string_literal: true

require 'rails-openapi-gen/version'
require 'rails-openapi-gen/logger'
require 'rails-openapi-gen/configuration'
require 'parser/current'
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
    # Returns the logger instance
    # @return [RailsOpenapiGen::Logger]
    def logger
      @logger ||= Logger.instance
    end
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
    include RailsOpenapiGen::Logging
    
    # Checks for missing OpenAPI comments and uncommitted changes
    # @return [void]
    def run
      logger.info("Checking for missing comments and uncommitted changes...", emoji: :debug)

      # Run OpenAPI generation to check for missing comments
      system('bin/rails openapi:generate') || system('bundle exec rails openapi:generate')

      # Check for uncommitted changes in openapi directory
      if system('git diff --quiet docs/api/ 2>/dev/null')
        logger.success("All checks passed!")
      else
        logger.error("Found uncommitted changes in OpenAPI files")
        logger.error(`git diff docs/api/`)
        exit 1
      end
    end
  end

  class Generator
    include RailsOpenapiGen::Logging
    
    # Runs the OpenAPI generation process
    # @return [void]
    def run
      # Load configuration
      RailsOpenapiGen.configuration.load_from_file

      routes = Parsers::RoutesParser.new.parse
      logger.info("Found #{routes.size} total routes")

      # Debug: Show filtering configuration
      config = RailsOpenapiGen.configuration

      # Apply filtering with debug output
      filtered_routes = routes.select do |route|
        included = config.route_included?(route[:path])
        included
      end

      logger.info("Processing #{filtered_routes.size} filtered routes")
      logger.debug("Filtered out #{routes.size - filtered_routes.size} routes")

      schemas = {}
      all_components = {}

      filtered_routes.each_with_index do |route, index|
        progress = "[#{index + 1}/#{filtered_routes.size}]"
        endpoint = "#{route[:method]} #{route[:path]}"
        logger.info("#{progress} Processing endpoint: #{endpoint}", emoji: :process)
        
        controller_info = Parsers::ControllerParser.new(route).parse

        unless controller_info[:jbuilder_path]
          logger.warn("#{progress} No Jbuilder template found for #{endpoint}")
          next
        end
        
        logger.debug("#{progress} Found Jbuilder: #{controller_info[:jbuilder_path]}")

        logger.debug("#{progress} Parsing Jbuilder template...")
        jbuilder_parser = Parsers::Jbuilder::JbuilderParser.new(controller_info[:jbuilder_path])
        ast_node = jbuilder_parser.parse

        # Collect components from this parser
        if jbuilder_parser.respond_to?(:ast_parser) && jbuilder_parser.ast_parser && jbuilder_parser.ast_parser.respond_to?(:partial_components)
          component_count = jbuilder_parser.ast_parser.partial_components.size
          if component_count > 0
            logger.debug("#{progress} Found #{component_count} partial components", emoji: :component)
            all_components.merge!(jbuilder_parser.ast_parser.partial_components)
          end
        end

        logger.debug("#{progress} Converting AST to OpenAPI schema...")
        schema = Processors::AstToSchemaProcessor.new.process_to_schema(ast_node)
        
        # Check if schema has meaningful content
        if schema && schema["properties"] && !schema["properties"].empty?
          logger.success("#{progress} ✓ Generated schema with #{schema["properties"].size} properties")
        elsif schema && schema["type"]
          logger.success("#{progress} ✓ Generated #{schema["type"]} schema")
        else
          logger.warn("#{progress} Generated empty or invalid schema")
        end
        
        schemas[route] = {
          schema: schema,
          parameters: controller_info[:parameters] || {},
          operation: {} # Operation data is not available in AST approach
        }
      rescue StandardError => e
        logger.error("#{progress} ❌ ERROR processing #{endpoint}: #{e.class} - #{e.message}")
        logger.error("#{progress} Stack trace: #{e.backtrace.first(3).join("\n")}")
        raise
      end

      logger.info("Completed processing all endpoints")
      logger.info("Generating YAML files...", emoji: :file)
      
      Generators::YamlGenerator.new(schemas, components: all_components).generate
      
      # Summary
      successful_schemas = schemas.count { |_, data| data[:schema] && !data[:schema].empty? }
      logger.success("OpenAPI specification generated successfully!")
      logger.info("📊 Summary: #{successful_schemas}/#{schemas.size} endpoints generated schemas")
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

    # NOTE: Old hash-based processing methods have been removed
    # The system now uses AST-based processing with AstToSchemaProcessor
  end
end
