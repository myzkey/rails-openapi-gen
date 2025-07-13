# frozen_string_literal: true

require_relative "ast_to_schema_processor"

module RailsOpenapiGen::Processors
  # High-level processor for generating complete OpenAPI schemas
  # Orchestrates the conversion from AST to full OpenAPI specification
  class OpenApiSchemaProcessor
    def initialize
      @ast_processor = AstToSchemaProcessor.new
    end

    # Generate complete OpenAPI response schema from AST
    # @param root_node [RailsOpenapiGen::AstNodes::BaseNode] Root AST node
    # @param operation_info [Hash, nil] Operation-level information
    # @return [Hash] Complete OpenAPI response schema
    def generate_response_schema(root_node, operation_info = nil)
      return default_response_schema unless root_node

      # Convert AST to schema
      schema = @ast_processor.process_to_schema(root_node)

      # Build response object
      response = {
        description: operation_info&.dig(:response_description) || 'Successful response',
        content: {
          'application/json' => {
            schema: schema
          }
        }
      }

      # Add examples if available
      if operation_info&.dig(:examples)
        response[:content]['application/json'][:examples] = operation_info[:examples]
      end

      {
        '200' => response
      }
    end

    # Generate complete OpenAPI operation from AST and operation info
    # @param root_node [RailsOpenapiGen::AstNodes::BaseNode] Root AST node
    # @param operation_info [Hash, nil] Operation-level information
    # @return [Hash] Complete OpenAPI operation
    def generate_operation(root_node, operation_info = nil)
      operation = {}

      # Add operation-level information
      if operation_info
        operation[:operationId] = operation_info[:operation_id] if operation_info[:operation_id]
        operation[:summary] = operation_info[:summary] if operation_info[:summary]
        operation[:description] = operation_info[:description] if operation_info[:description]
        operation[:tags] = operation_info[:tags] if operation_info[:tags]
      end

      # Add responses
      operation[:responses] = generate_response_schema(root_node, operation_info)

      # Add parameters if specified
      if operation_info&.dig(:parameters)
        operation[:parameters] = operation_info[:parameters]
      end

      # Add request body if specified
      if operation_info&.dig(:request_body)
        operation[:requestBody] = operation_info[:request_body]
      end

      operation
    end

    # Generate path item from AST and operation info
    # @param method [String] HTTP method (get, post, etc.)
    # @param root_node [RailsOpenapiGen::AstNodes::BaseNode] Root AST node
    # @param operation_info [Hash, nil] Operation-level information
    # @return [Hash] OpenAPI path item
    def generate_path_item(method, root_node, operation_info = nil)
      {
        method.downcase => generate_operation(root_node, operation_info)
      }
    end

    # Generate component schema from AST
    # @param root_node [RailsOpenapiGen::AstNodes::BaseNode] Root AST node
    # @param schema_name [String] Name for the schema component
    # @return [Hash] Component schema
    def generate_component_schema(root_node, schema_name)
      schema = @ast_processor.process_to_schema(root_node)

      {
        schema_name => schema
      }
    end

    # Validate generated schema
    # @param schema [Hash] OpenAPI schema to validate
    # @return [Array<String>] Array of validation errors (empty if valid)
    def validate_schema(schema)
      errors = []

      # Basic validation
      unless schema.is_a?(Hash)
        errors << "Schema must be a hash"
        return errors
      end

      # Check for required fields in responses
      if schema.dig('200', 'content', 'application/json', 'schema')
        schema_obj = schema['200']['content']['application/json']['schema']
        errors.concat(validate_schema_object(schema_obj, 'root'))
      end

      errors
    end

    # Extract missing comment information
    # @param root_node [RailsOpenapiGen::AstNodes::BaseNode] Root AST node
    # @return [Array<Hash>] Array of missing comment information
    def extract_missing_comments(root_node)
      missing = []
      extract_missing_comments_recursive(root_node, [], missing)
      missing
    end

    private

    # Default response schema for error cases
    # @return [Hash] Default response schema
    def default_response_schema
      {
        '200' => {
          description: 'Successful response',
          content: {
            'application/json' => {
              schema: {
                type: 'object',
                description: 'TODO: MISSING COMMENT'
              }
            }
          }
        }
      }
    end

    # Validate a schema object recursively
    # @param schema [Hash] Schema object to validate
    # @param path [String] Current path for error reporting
    # @return [Array<String>] Validation errors
    def validate_schema_object(schema, path)
      errors = []

      unless schema.is_a?(Hash)
        errors << "Schema at #{path} must be a hash"
        return errors
      end

      # Check for missing type
      unless schema[:type] || schema['type']
        errors << "Schema at #{path} is missing type"
      end

      # Validate properties if it's an object
      type = schema[:type] || schema['type']
      if type == 'object'
        properties = schema[:properties] || schema['properties']
        if properties.is_a?(Hash)
          properties.each do |prop_name, prop_schema|
            errors.concat(validate_schema_object(prop_schema, "#{path}.#{prop_name}"))
          end
        end
      end

      # Validate array items
      if type == 'array'
        items = schema[:items] || schema['items']
        if items.is_a?(Hash)
          errors.concat(validate_schema_object(items, "#{path}[]"))
        end
      end

      errors
    end

    # Recursively extract missing comment information
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Current node
    # @param path [Array<String>] Current path
    # @param missing [Array<Hash>] Array to collect missing comments
    # @return [void]
    def extract_missing_comments_recursive(node, path, missing)
      return unless node

      # Check if node has missing comment
      if node.respond_to?(:comment_data) &&
         (!node.comment_data || node.comment_data.description.nil?)
        missing << {
          path: path.join('.'),
          property: node.respond_to?(:property_name) ? node.property_name : 'unknown',
          type: node.class.name.split('::').last
        }
      end

      # Recurse into child nodes
      if node.respond_to?(:properties)
        node.properties.each do |child|
          child_path = path + [child.respond_to?(:property_name) ? child.property_name : 'unknown']
          extract_missing_comments_recursive(child, child_path, missing)
        end
      elsif node.respond_to?(:items)
        node.items.each_with_index do |child, index|
          child_path = path + ["[#{index}]"]
          extract_missing_comments_recursive(child, child_path, missing)
        end
      end
    end
  end
end
