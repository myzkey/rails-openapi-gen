# frozen_string_literal: true

module RailsOpenapiGen
  module AstNodes
    autoload :BaseNode, "rails-openapi-gen/ast_nodes/base_node"
    autoload :PropertyNode, "rails-openapi-gen/ast_nodes/property_node"
    autoload :ArrayNode, "rails-openapi-gen/ast_nodes/array_node"
    autoload :PartialNode, "rails-openapi-gen/ast_nodes/partial_node"
    autoload :ObjectNode, "rails-openapi-gen/ast_nodes/object_node"
    autoload :CommentData, "rails-openapi-gen/ast_nodes/comment_data"
    autoload :NodeFactory, "rails-openapi-gen/ast_nodes/node_factory"

    # Legacy compatibility classes - will be deprecated
    # These maintain backward compatibility with existing code
    class PropertyNodeFactory < NodeFactory
      # Delegate to NodeFactory for backward compatibility
      class << self
        def from_hash(hash_data)
          NodeFactory.from_hash(hash_data)
        end

        def create_simple(property:, comment_data: nil, is_conditional: false)
          NodeFactory.create_property(
            property_name: property,
            comment_data: comment_data,
            is_conditional: is_conditional
          )
        end

        def create_array(property:, comment_data: nil, is_conditional: false, array_item_properties: [])
          node = NodeFactory.create_array(
            property_name: property,
            comment_data: comment_data,
            is_conditional: is_conditional
          )
          array_item_properties.each { |item| node.add_item(item) }
          node
        end

        def create_object(property:, comment_data: nil, is_conditional: false, nested_properties: [])
          node = NodeFactory.create_object(
            property_name: property,
            comment_data: comment_data,
            is_conditional: is_conditional
          )
          nested_properties.each { |prop| node.add_property(prop) }
          node
        end

        def create_array_root(comment_data: nil, array_item_properties: [])
          node = NodeFactory.create_array(
            comment_data: comment_data,
            is_root_array: true
          )
          array_item_properties.each { |item| node.add_item(item) }
          node
        end
      end
    end

    # Legacy property node classes for backward compatibility
    class SimplePropertyNode < PropertyNode
      def initialize(property:, comment_data: nil, is_conditional: false)
        super(property_name: property, comment_data: comment_data, is_conditional: is_conditional)
      end

      def property
        property_name
      end
    end

    class ArrayPropertyNode < ArrayNode
      def initialize(property:, comment_data: nil, is_conditional: false, array_item_properties: [])
        super(property_name: property, comment_data: comment_data, is_conditional: is_conditional)
        array_item_properties.each { |item| add_item(item) }
      end

      def property
        property_name
      end

      def array_item_properties
        items
      end

      def add_item_property(property_node)
        add_item(property_node)
      end
    end

    class ObjectPropertyNode < ObjectNode
      def initialize(property:, comment_data: nil, is_conditional: false, nested_properties: [])
        super(property_name: property, comment_data: comment_data, is_conditional: is_conditional)
        nested_properties.each { |prop| add_property(prop) }
      end

      def property
        property_name
      end

      def nested_properties
        properties
      end

      def add_nested_property(property_node)
        add_property(property_node)
      end
    end

    class ArrayRootNode < ArrayNode
      def initialize(comment_data: nil, array_item_properties: [])
        super(property_name: 'items', comment_data: comment_data, is_root_array: true)
        array_item_properties.each { |item| add_item(item) }
      end

      def property
        property_name
      end

      def array_item_properties
        items
      end

      def add_item_property(property_node)
        add_item(property_node)
      end
    end
  end
end
