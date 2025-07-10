# frozen_string_literal: true

module RailsOpenapiGen::AstNodes
  # Represents an object node in Jbuilder template (json.object do...end)
  class ObjectNode < BaseNode
    attr_reader :property_name, :comment_data, :is_conditional

    def initialize(property_name:, comment_data: nil, is_conditional: false, parent: nil, metadata: {})
      super(parent: parent, metadata: metadata)
      @property_name = property_name
      @comment_data = comment_data || CommentData.new(type: 'object')
      @is_conditional = is_conditional
    end

    # Add a property to this object
    # @param property_node [BaseNode] Property node to add
    # @return [BaseNode] The added property node
    def add_property(property_node)
      add_child(property_node)
    end

    # Get all properties in this object
    # @return [Array<BaseNode>] Property nodes
    def properties
      @children
    end

    # Get required properties for OpenAPI schema
    # @return [Array<String>] Names of required properties
    def required_properties
      properties.select(&:required?).map(&:property_name)
    end

    # Get optional properties for OpenAPI schema
    # @return [Array<String>] Names of optional properties
    def optional_properties
      properties.select(&:optional?).map(&:property_name)
    end

    # Check if this object is required in OpenAPI schema
    # @return [Boolean] True if object is required
    def required?
      @comment_data.required? && !@is_conditional
    end

    # Check if this object is optional in OpenAPI schema
    # @return [Boolean] True if object is optional
    def optional?
      !required?
    end

    # Get the description for this object
    # @return [String, nil] Object description
    def description
      @comment_data.description
    end

    # Find a property by name
    # @param name [String] Property name to find
    # @return [BaseNode, nil] Property node or nil if not found
    def find_property(name)
      properties.find { |prop| prop.property_name == name }
    end

    # Check if object has any properties
    # @return [Boolean] True if object has properties
    def has_properties?
      !properties.empty?
    end

    # Convert to hash representation
    # @return [Hash] Hash representation
    def to_h
      super.merge(
        property_name: @property_name,
        comment_data: @comment_data&.to_h,
        is_conditional: @is_conditional,
        required: required?,
        openapi_type: 'object',
        description: description,
        properties: properties.map(&:to_h),
        required_properties: required_properties,
        optional_properties: optional_properties
      ).compact
    end

    # Accept visitor for visitor pattern
    # @param visitor [Object] Visitor object
    # @return [Object] Result from visitor
    def accept(visitor)
      visitor.visit_object(self)
    end
  end
end