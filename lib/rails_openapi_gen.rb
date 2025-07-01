# frozen_string_literal: true

require "rails_openapi_gen/version"
require "rails_openapi_gen/configuration"
require "rails_openapi_gen/parsers/comment_parser"
require "rails_openapi_gen/generators/yaml_generator"

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
    def generate
      Generator.new.run
    end

    def check
      Checker.new.run
    end
  end

  class Generator
    def run
      # Load configuration
      RailsOpenapiGen.configuration.load_from_file
      
      routes = Parsers::RoutesParser.new.parse
      filtered_routes = routes.select { |route| RailsOpenapiGen.configuration.route_included?(route[:path]) }
      
      schemas = {}

      filtered_routes.each do |route|
        controller_info = Parsers::ControllerParser.new(route).parse
        
        if controller_info[:jbuilder_path]
          jbuilder_ast = Parsers::JbuilderParser.new(controller_info[:jbuilder_path]).parse
          schema = build_schema(jbuilder_ast)
          schemas[route] = schema
        end
      end

      Generators::YamlGenerator.new(schemas).generate
      puts "✅ OpenAPI specification generated successfully!"
    end

    private

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
        schema["required"] << property if comment_data[:required] == "true"
      end

      schema
    end

    def build_array_schema(ast)
      # For json.array! responses, return array schema
      item_properties = {}
      required_fields = []

      ast.each do |node|
        next if node[:is_array_root]
        
        property = node[:property]
        comment_data = node[:comment_data] || {}
        
        property_schema = build_property_schema(node)
        item_properties[property] = property_schema
        required_fields << property if comment_data[:required] == "true"
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

    def build_property_schema(node)
      comment_data = node[:comment_data] || {}
      property_schema = {}

      # Handle different property types
      if node[:is_object] || node[:is_nested]
        property_schema["type"] = "object"
        property_schema["description"] = comment_data[:description] || "Nested object"
      elsif node[:is_array]
        if comment_data[:items]
          property_schema = comment_data.dup
        else
          property_schema["type"] = "array"
          property_schema["items"] = { "type" => "object" }
        end
      elsif comment_data[:type] && comment_data[:type] != "TODO: MISSING COMMENT"
        property_schema["type"] = comment_data[:type]
      else
        property_schema["type"] = "string"
        property_schema["description"] = "TODO: MISSING COMMENT - Add @openapi comment"
      end

      # Add common properties
      property_schema["description"] = comment_data[:description] if comment_data[:description]
      property_schema["enum"] = comment_data[:enum] if comment_data[:enum]

      property_schema
    end
  end

  class Checker
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