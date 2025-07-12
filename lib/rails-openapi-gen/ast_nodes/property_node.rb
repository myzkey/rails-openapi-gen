# frozen_string_literal: true

module RailsOpenapiGen
  module AstNodes
  # Represents a property node in Jbuilder template (json.property_name)
  class PropertyNode < BaseNode
    attr_reader :property_name # json.xxx
    attr_reader :comment_data # @openapi comments
    attr_reader :is_conditional # if/else
    attr_reader :is_component_ref # whether this is a component reference
    attr_reader :component_name # name of referenced component

    def initialize(property_name:, comment_data: nil, is_conditional: false, is_component_ref: false, component_name: nil, parent: nil, metadata: {})
      super(parent: parent, metadata: metadata)
      @property_name = property_name
      @comment_data = comment_data || CommentData.new
      @is_conditional = is_conditional
      @is_component_ref = is_component_ref
      @component_name = component_name
    end

    # Check if this property is required in OpenAPI schema
    # @return [Boolean] True if property is required
    def required?
      @comment_data.required? && !@is_conditional
    end

    # Check if this property is optional in OpenAPI schema
    # @return [Boolean] True if property is optional
    def optional?
      !required?
    end

    # Get the OpenAPI type for this property
    # @return [String] OpenAPI type
    def openapi_type
      @comment_data.type || 'string'
    end

    # Get the description for this property
    # @return [String, nil] Property description
    def description
      @comment_data.description
    end

    # Get enum values if specified
    # @return [Array, nil] Enum values
    def enum_values
      @comment_data.enum
    end

    # Convert to hash representation
    # @return [Hash] Hash representation
    def to_h
      super.merge(
        property_name: @property_name,
        comment_data: @comment_data&.to_h,
        is_conditional: @is_conditional,
        is_component_ref: @is_component_ref,
        component_name: @component_name,
        required: required?,
        openapi_type: openapi_type,
        description: description,
        enum: enum_values,
        # Backward compatibility - also provide property for Generator
        property: @property_name
      ).compact
    end

    # Accept visitor for visitor pattern
    # @param visitor [Object] Visitor object
    # @return [Object] Result from visitor
    def accept(visitor)
      visitor.visit_property(self)
    end
  end
  end
end