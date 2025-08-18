# frozen_string_literal: true

module RailsOpenapiGen
  module Processors
    # Processor for building OpenAPI schemas from AST properties
    # Contains all the schema building logic moved from Generator
    class OpenapiSchemaProcessor
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
    end
  end
end