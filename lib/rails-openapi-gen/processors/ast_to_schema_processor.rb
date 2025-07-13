# frozen_string_literal: true

require_relative "base_processor"

module RailsOpenapiGen::Processors
  # Processor that converts AST nodes to OpenAPI schema format
  # Implements the visitor pattern to handle different node types
  class AstToSchemaProcessor < BaseProcessor
    def initialize
      super()
      @schema = {}
      @required_properties = []
    end

    # Process root node and return OpenAPI schema
    # @param root_node [RailsOpenapiGen::AstNodes::BaseNode] Root AST node
    # @return [Hash] OpenAPI schema
    def process_to_schema(root_node)
      @schema = {}
      @required_properties = []

      puts "🔍 DEBUG: Using NEW AstToSchemaProcessor with node: #{root_node.class.name}" if ENV['RAILS_OPENAPI_DEBUG']
      if root_node.respond_to?(:properties) && ENV['RAILS_OPENAPI_DEBUG']
        puts "🔍 DEBUG: Root node has #{root_node.properties.size} properties"
        root_node.properties.each_with_index do |prop, i|
          puts "🔍 DEBUG: Property #{i}: #{prop.property_name} (#{prop.class.name})"
        end
      end

      result = process(root_node)

      # Handle root array case
      if root_node.is_a?(RailsOpenapiGen::AstNodes::ArrayNode) && root_node.root_array?
        # For root arrays, return the result directly since visit_array already creates the array schema
        result || { 'type' => 'array', 'items' => { 'type' => 'object' } }
      else
        result || { 'type' => 'object' }
      end
    end

    # Visit a property node
    # @param node [RailsOpenapiGen::AstNodes::PropertyNode] Property node
    # @return [Hash] Property schema
    def visit_property(node)
      # If this is a component reference, return a $ref with prefix removed
      if node.is_component_ref && node.component_name
        # Remove component prefix from schema name in $ref
        config = RailsOpenapiGen.configuration
        schema_name_without_prefix = config.remove_component_prefix(node.component_name)
        return { '$ref' => "#/components/schemas/#{schema_name_without_prefix}" }
      end

      schema = build_basic_schema(node)

      # Add enum if specified
      if node.comment_data&.has_enum?
        schema['enum'] = node.comment_data.enum
      end

      # Add format if specified
      if node.comment_data&.has_format?
        schema['format'] = node.comment_data.format
      end

      # Add example if specified
      if node.comment_data&.has_example?
        schema['example'] = node.comment_data.example
      end

      schema
    end

    # Visit an array node
    # @param node [RailsOpenapiGen::AstNodes::ArrayNode] Array node
    # @return [Hash] Array schema
    def visit_array(node)
      schema = {
        'type' => 'array',
        'description' => extract_description(node.comment_data)
      }.compact

      # Process array items
      if node.items.any?
        # Check if all items are properties (from partial processing)
        # If so, combine them into a single object schema
        if node.items.all? { |item| item.is_a?(RailsOpenapiGen::AstNodes::PropertyNode) }
          # Combine all property nodes into a single object schema
          properties = {}
          required = []

          node.items.each do |property_node|
            prop_schema = process(property_node)
            next unless prop_schema

            properties[property_node.property_name] = prop_schema

            # Add to required if property is required
            if required?(property_node)
              required << property_node.property_name
            end
          end

          object_schema = { 'type' => 'object' }
          object_schema['properties'] = properties if properties.any?
          object_schema['required'] = required if required.any?

          schema['items'] = object_schema
        else
          # If we have actual item nodes, process them
          item_schemas = process_nodes(node.items)

          schema['items'] = if item_schemas.length == 1
                              item_schemas.first
                            elsif item_schemas.length > 1
                              # Multiple item types - use oneOf
                              { 'oneOf' => item_schemas }
                            else
                              { 'type' => 'object' }
                            end
        end
      else
        # Use comment data for item type
        items_spec = node.comment_data&.array_items
        schema['items'] = items_spec || { 'type' => 'object' }
      end

      schema
    end

    # Visit an object node
    # @param node [RailsOpenapiGen::AstNodes::ObjectNode] Object node
    # @return [Hash] Object schema
    def visit_object(node)
      schema = {
        'type' => 'object',
        'description' => extract_description(node.comment_data)
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

        schema['properties'] = properties if properties.any?
        schema['required'] = required if required.any?
      end

      schema
    end

    # Visit a partial node
    # @param node [RailsOpenapiGen::AstNodes::PartialNode] Partial node
    # @return [Hash] Schema from partial
    def visit_partial(node)
      puts "🔍 DEBUG: Processing partial node: #{node.partial_path}, properties: #{node.properties.size}" if ENV['RAILS_OPENAPI_DEBUG']

      # Process the properties from the parsed partial
      if node.properties.any?
        # Create an object schema with the partial's properties
        properties = {}
        required = []

        node.properties.each do |property|
          puts "🔍 DEBUG: Processing partial property: #{property.property_name} (#{property.class.name})" if ENV['RAILS_OPENAPI_DEBUG']
          prop_schema = process(property)
          next unless prop_schema

          properties[property.property_name] = prop_schema

          if required?(property)
            required << property.property_name
          end
        end

        schema = { 'type' => 'object' }
        schema['properties'] = properties if properties.any?
        schema['required'] = required if required.any?
        schema['description'] = extract_description(node.comment_data) if node.comment_data&.description

        puts "🔍 DEBUG: Partial schema generated: #{schema.keys}" if ENV['RAILS_OPENAPI_DEBUG']
        schema
      else
        puts "🔍 DEBUG: Partial has no properties, using fallback" if ENV['RAILS_OPENAPI_DEBUG']
        # Fallback to basic object schema
        {
          'type' => 'object',
          'description' => extract_description(node.comment_data) || "Partial: #{node.partial_path}"
        }.compact
      end
    end

    # Visit an unknown node type
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Unknown node
    # @return [Hash] Basic object schema
    def visit_unknown(_node)
      {
        'type' => 'object',
        'description' => 'Unknown node type'
      }
    end

    private

    # Build basic schema from node
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Node
    # @return [Hash] Basic schema
    def build_basic_schema(node)
      {
        'type' => extract_type(node.comment_data),
        'description' => extract_description(node.comment_data)
      }.compact
    end
  end
end
