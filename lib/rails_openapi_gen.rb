# frozen_string_literal: true

require "rails_openapi_gen/version"
require "rails_openapi_gen/configuration"
require "rails_openapi_gen/parsers/comment_parser"
require "rails_openapi_gen/generators/yaml_generator"
require "rails_openapi_gen/importer"

# Rails integration is handled by Engine

# Load Rails Engine if Rails is available
if defined?(Rails::Engine)
  require "rails_openapi_gen/engine"
  
  # Only load parser-dependent components if parser gem is available
  begin
    require "parser/current"
    require "rails_openapi_gen/parsers/routes_parser"
    require "rails_openapi_gen/parsers/controller_parser"
    require "rails_openapi_gen/parsers/jbuilder_parser"
  rescue LoadError
    # parser gem not available, skip these components
  end
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

  class Generator
    # Runs the OpenAPI generation process
    # @return [void]
    def run
      # Load configuration
      RailsOpenapiGen.configuration.load_from_file
      
      routes = Parsers::RoutesParser.new.parse
      filtered_routes = routes.select { |route| RailsOpenapiGen.configuration.route_included?(route[:path]) }
      
      schemas = {}

      filtered_routes.each do |route|
        controller_info = Parsers::ControllerParser.new(route).parse
        
        if controller_info[:jbuilder_path]
          jbuilder_result = Parsers::JbuilderParser.new(controller_info[:jbuilder_path]).parse
          schema = build_schema(jbuilder_result[:properties])
          schemas[route] = {
            schema: schema,
            parameters: controller_info[:parameters] || {},
            operation: jbuilder_result[:operation]
          }
        end
      end

      Generators::YamlGenerator.new(schemas).generate
      puts "✅ OpenAPI specification generated successfully!"
    end

    private

    # Builds schema from parsed AST nodes
    # @param ast [Array<Hash>] Array of parsed AST nodes
    # @return [Hash] OpenAPI schema definition
    def build_schema(ast)
      # Check if this is an array response (json.array!)
      if ast.any? { |node| node[:is_array_root] }
        return build_array_schema(ast)
      end
      
      schema = { "type" => "object", "properties" => {}, "required" => [] }

      ast.each do |node|
        property = node[:property]
        comment_data = node[:comment_data] || {}

        # Skip array root items as they're handled separately
        next if node[:is_array_root]

        property_schema = build_property_schema(node)
        
        schema["properties"][property] = property_schema
        # Don't mark conditional properties as required, even if they have required:true
        if comment_data[:required] != "false" && !node[:is_conditional]
          schema["required"] << property
        end
      end

      schema
    end

    # Builds array schema from AST nodes containing json.array!
    # @param ast [Array<Hash>] Array of parsed AST nodes
    # @return [Hash] OpenAPI array schema definition
    def build_array_schema(ast)
      # For json.array! responses, return array schema
      item_properties = {}
      required_fields = []

      # Find the array root node to check for array_item_properties
      array_root_node = ast.find { |node| node[:is_array_root] }
      
      if array_root_node && array_root_node[:array_item_properties]
        # Use properties from the parsed partial
        array_root_node[:array_item_properties].each do |node|
          property = node[:property]
          comment_data = node[:comment_data] || {}
          
          property_schema = build_property_schema(node)
          item_properties[property] = property_schema
          if comment_data[:required] != "false" && !node[:is_conditional]
            required_fields << property
          end
        end
      else
        # Fall back to looking for non-root properties
        ast.each do |node|
          next if node[:is_array_root]
          
          property = node[:property]
          comment_data = node[:comment_data] || {}
          
          property_schema = build_property_schema(node)
          item_properties[property] = property_schema
          if comment_data[:required] != "false" && !node[:is_conditional]
            required_fields << property
          end
        end
      end

      {
        "type" => "array",
        "items" => {
          "type" => "object",
          "properties" => item_properties,
          "required" => required_fields
        }
      }
    end

    # Builds property schema from a single AST node
    # @param node [Hash] Parsed AST node containing property information
    # @return [Hash] OpenAPI property schema
    def build_property_schema(node)
      comment_data = node[:comment_data] || {}
      property_schema = {}

      # Handle different property types
      if node[:is_object] || node[:is_nested]
        property_schema["type"] = "object"
        
        # Build nested properties if they exist
        if node[:nested_properties] && !node[:nested_properties].empty?
          nested_schema = build_nested_object_schema(node[:nested_properties])
          property_schema["properties"] = nested_schema[:properties]
          property_schema["required"] = nested_schema[:required] if nested_schema[:required] && !nested_schema[:required].empty?
        end
      elsif node[:is_array]
        property_schema["type"] = "array"
        
        if node[:array_item_properties] && !node[:array_item_properties].empty?
          # Build items schema from array iteration block
          items_schema = build_nested_object_schema(node[:array_item_properties])
          items_def = {
            "type" => "object",
            "properties" => items_schema[:properties]
          }
          items_def["required"] = items_schema[:required] if items_schema[:required] && !items_schema[:required].empty?
          property_schema["items"] = items_def
        elsif comment_data[:items]
          # Use specified items type from comment
          property_schema["items"] = { "type" => comment_data[:items] }
        else
          # Default to object items
          property_schema["items"] = { "type" => "object" }
        end
      elsif comment_data[:type] && comment_data[:type] != "TODO: MISSING COMMENT"
        property_schema["type"] = comment_data[:type]
        
        # Handle array types
        if comment_data[:type] == "array"
          if comment_data[:items]
            # Use specified items type
            property_schema["items"] = { "type" => comment_data[:items] }
          else
            # Default to string items if no items type is specified
            property_schema["items"] = { "type" => "string" }
          end
        end
      else
        # Only show TODO message if no @openapi comment exists at all
        property_schema["type"] = "string"
        if comment_data.nil? || comment_data.empty?
          property_schema["description"] = "TODO: MISSING COMMENT - Add @openapi comment"
        end
      end

      # Add common properties
      property_schema["description"] = comment_data[:description] if comment_data[:description]
      property_schema["enum"] = comment_data[:enum] if comment_data[:enum]

      property_schema
    end
    
    # Builds schema for nested object properties
    # @param nested_properties [Array<Hash>] Array of nested property nodes
    # @return [Hash] Schema with properties and required fields
    def build_nested_object_schema(nested_properties)
      schema = { properties: {}, required: [] }
      
      nested_properties.each do |node|
        property = node[:property]
        comment_data = node[:comment_data] || {}
        
        property_schema = build_property_schema(node)
        schema[:properties][property] = property_schema
        if comment_data[:required] != "false" && !node[:is_conditional]
          schema[:required] << property
        end
      end
      
      schema
    end
  end

  class Checker
    # Runs checks for missing comments and uncommitted changes
    # @return [void]
    def run
      system("bin/rails openapi:generate")
      
      missing_comments = `grep -r "TODO: MISSING COMMENT" openapi/`.strip
      unless missing_comments.empty?
        puts "❌ Missing @openapi comments found!"
        exit 1
      end

      diff = `git diff --name-only openapi/`.strip
      unless diff.empty?
        puts "❌ OpenAPI spec has uncommitted changes!"
        exit 1
      end

      puts "✅ OpenAPI spec is up to date!"
    end
  end
end