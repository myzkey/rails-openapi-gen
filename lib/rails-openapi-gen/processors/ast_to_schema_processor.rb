# frozen_string_literal: true

require_relative "base_processor"

module RailsOpenapiGen::Processors
  # Processor that converts AST nodes to OpenAPI schema format
  # Implements the visitor pattern to handle different node types
  class AstToSchemaProcessor < BaseProcessor
    def initialize
      @schema = {}
      @required_properties = []
    end

    # Process root node and return OpenAPI schema
    # @param root_node [RailsOpenapiGen::AstNodes::BaseNode] Root AST node
    # @return [Hash] OpenAPI schema
    def process_to_schema(root_node)
      @schema = {}
      @required_properties = []
      
      result = process(root_node)
      
      # Handle root array case
      if root_node.is_a?(RailsOpenapiGen::AstNodes::ArrayNode) && root_node.root_array?
        {
          type: 'array',
          items: result || { type: 'object' }
        }
      else
        result || { type: 'object' }
      end
    end

    # Visit a property node
    # @param node [RailsOpenapiGen::AstNodes::PropertyNode] Property node
    # @return [Hash] Property schema
    def visit_property(node)
      schema = build_basic_schema(node)
      
      # Add enum if specified
      if node.comment_data&.has_enum?
        schema[:enum] = node.comment_data.enum
      end
      
      # Add format if specified
      if node.comment_data&.has_format?
        schema[:format] = node.comment_data.format
      end
      
      # Add example if specified
      if node.comment_data&.has_example?
        schema[:example] = node.comment_data.example
      end
      
      schema
    end

    # Visit an array node
    # @param node [RailsOpenapiGen::AstNodes::ArrayNode] Array node
    # @return [Hash] Array schema
    def visit_array(node)
      schema = {
        type: 'array',
        description: extract_description(node.comment_data)
      }.compact
      
      # Process array items
      if node.items.any?
        # If we have actual item nodes, process them
        item_schemas = process_nodes(node.items)
        
        if item_schemas.length == 1
          schema[:items] = item_schemas.first
        elsif item_schemas.length > 1
          # Multiple item types - use oneOf
          schema[:items] = { oneOf: item_schemas }
        else
          schema[:items] = { type: 'object' }
        end
      else
        # Use comment data for item type
        items_spec = node.comment_data&.array_items
        schema[:items] = items_spec || { type: 'object' }
      end
      
      schema
    end

    # Visit an object node
    # @param node [RailsOpenapiGen::AstNodes::ObjectNode] Object node
    # @return [Hash] Object schema
    def visit_object(node)
      schema = {
        type: 'object',
        description: extract_description(node.comment_data)
      }.compact
      
      # Process properties
      if node.properties.any?
        properties = {}
        required = []
        
        node.properties.each do |property|
          prop_schema = process(property)
          next unless prop_schema
          
          properties[property.property_name] = prop_schema
          
          # Add to required if property is required
          if required?(property)
            required << property.property_name
          end
        end
        
        schema[:properties] = properties if properties.any?
        schema[:required] = required if required.any?
      end
      
      schema
    end

    # Visit a partial node
    # @param node [RailsOpenapiGen::AstNodes::PartialNode] Partial node
    # @return [Hash] Schema from partial
    def visit_partial(node)
      # Process the properties from the parsed partial
      if node.properties.any?
        # Create an object schema with the partial's properties
        properties = {}
        required = []
        
        node.properties.each do |property|
          prop_schema = process(property)
          next unless prop_schema
          
          properties[property.property_name] = prop_schema
          
          if required?(property)
            required << property.property_name
          end
        end
        
        schema = { type: 'object' }
        schema[:properties] = properties if properties.any?
        schema[:required] = required if required.any?
        schema[:description] = extract_description(node.comment_data) if node.comment_data&.description
        
        schema
      else
        # Fallback to basic object schema
        {
          type: 'object',
          description: extract_description(node.comment_data) || "Partial: #{node.partial_path}"
        }.compact
      end
    end

    # Visit an unknown node type
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Unknown node
    # @return [Hash] Basic object schema
    def visit_unknown(node)
      {
        type: 'object',
        description: 'Unknown node type'
      }
    end

    private

    # Build basic schema from node
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Node
    # @return [Hash] Basic schema
    def build_basic_schema(node)
      schema = {
        type: extract_type(node.comment_data),
        description: extract_description(node.comment_data)
      }.compact
      
      schema
    end
  end
end