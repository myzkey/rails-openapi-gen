# frozen_string_literal: true

module RailsOpenapiGen::AstNodes
  # Represents an object node in Jbuilder template (json.object do...end)
  class ObjectNode < BaseNode
    attr_reader :property_name, :comment_data, :is_conditional # json.xxx # @openapi comments # if/else

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
      properties.select do |property|
        if property.respond_to?(:required?)
          property.required?
        else
          # Handle legacy Hash objects
          property.is_a?(Hash) && property[:required] == true
        end
      end.map do |property|
        if property.respond_to?(:property_name)
          property.property_name
        else
          # Handle legacy Hash objects
          property[:property_name] || property[:property]
        end
      end.compact
    end

    # Get optional properties for OpenAPI schema
    # @return [Array<String>] Names of optional properties
    def optional_properties
      properties.select do |property|
        if property.respond_to?(:optional?)
          property.optional?
        else
          # Handle legacy Hash objects
          property.is_a?(Hash) && property[:required] != true
        end
      end.map do |property|
        if property.respond_to?(:property_name)
          property.property_name
        else
          # Handle legacy Hash objects
          property[:property_name] || property[:property]
        end
      end.compact
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
      properties.find do |prop|
        if prop.respond_to?(:property_name)
          prop.property_name == name
        else
          # Handle legacy Hash objects
          (prop[:property_name] || prop[:property]) == name
        end
      end
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
        properties: properties.map { |prop| prop.respond_to?(:to_h) ? prop.to_h : prop },
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
