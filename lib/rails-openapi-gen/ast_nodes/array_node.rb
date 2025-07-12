# frozen_string_literal: true

module RailsOpenapiGen::AstNodes
  # Represents an array node in Jbuilder template (json.array! or json.property @collection)
  class ArrayNode < BaseNode
    attr_reader :property_name, :comment_data, :is_conditional, :is_root_array

    def initialize(property_name: nil, comment_data: nil, is_conditional: false, is_root_array: false, parent: nil, metadata: {})
      super(parent: parent, metadata: metadata)
      @property_name = property_name || (is_root_array ? 'items' : nil)
      @comment_data = comment_data || CommentData.new(type: 'array')
      @is_conditional = is_conditional
      @is_root_array = is_root_array
    end

    # Add an item property to this array
    # @param item_node [BaseNode] Item node to add
    # @return [BaseNode] The added item node
    def add_item(item_node)
      add_child(item_node)
    end

    # Get all item properties in this array
    # @return [Array<BaseNode>] Array item nodes
    def items
      @children
    end

    # Check if this array is required in OpenAPI schema
    # @return [Boolean] True if array is required
    def required?
      @comment_data.required? && !@is_conditional
    end

    # Check if this array is optional in OpenAPI schema
    # @return [Boolean] True if array is optional
    def optional?
      !required?
    end

    # Get the OpenAPI type for array items
    # @return [String] OpenAPI type for items
    def item_type
      return 'object' if items.any?
      
      # Check comment data for item type specification
      if @comment_data.items
        case @comment_data.items
        when Hash
          @comment_data.items[:type] || 'object'
        when String
          @comment_data.items
        else
          'object'
        end
      else
        'object'
      end
    end

    # Get the description for this array
    # @return [String, nil] Array description
    def description
      @comment_data.description
    end

    # Check if this is a root array (json.array! at template root)
    # @return [Boolean] True if this is a root array
    def root_array?
      @is_root_array
    end

    # Convert to hash representation
    # @return [Hash] Hash representation
    def to_h
      items_hash = items.map { |item| item.respond_to?(:to_h) ? item.to_h : item }
      super.merge(
        property_name: @property_name,
        comment_data: @comment_data&.to_h,
        is_conditional: @is_conditional,
        is_root_array: @is_root_array,
        required: required?,
        openapi_type: 'array',
        item_type: item_type,
        description: description,
        items: items_hash,
        # Backward compatibility - also provide array_item_properties for Generator
        array_item_properties: items_hash,
        # Backward compatibility - also provide is_array_root for Generator
        is_array_root: @is_root_array
      ).compact
    end

    # Accept visitor for visitor pattern
    # @param visitor [Object] Visitor object
    # @return [Object] Result from visitor
    def accept(visitor)
      visitor.visit_array(self)
    end
  end
end