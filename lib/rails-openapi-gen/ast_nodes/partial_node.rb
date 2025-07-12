# frozen_string_literal: true

module RailsOpenapiGen::AstNodes
  # Represents a partial node in Jbuilder template (json.partial!)
  class PartialNode < BaseNode
    attr_reader :partial_path, :property_name, :comment_data, :is_conditional, :local_variables

    def initialize(
      partial_path:,
      property_name: nil,
      comment_data: nil,
      is_conditional: false,
      local_variables: {},
      parent: nil,
      metadata: {}
    )
      super(parent: parent, metadata: metadata)
      @partial_path = partial_path
      @property_name = property_name
      @comment_data = comment_data || CommentData.new
      @is_conditional = is_conditional
      @local_variables = local_variables
    end

    # Resolve the absolute path of the partial
    # @param base_path [String] Base path for resolution
    # @return [String] Resolved partial path
    def resolve_path(base_path = nil)
      return @partial_path if @partial_path.start_with?('/')

      if base_path
        File.join(File.dirname(base_path), "#{@partial_path}.json.jbuilder")
      else
        "#{@partial_path}.json.jbuilder"
      end
    end

    # Check if this partial is required in OpenAPI schema
    # @return [Boolean] True if partial is required
    def required?
      @comment_data.required? && !@is_conditional
    end

    # Check if this partial is optional in OpenAPI schema
    # @return [Boolean] True if partial is optional
    def optional?
      !required?
    end

    # Get the description for this partial
    # @return [String, nil] Partial description
    def description
      @comment_data.description
    end

    # Check if partial has local variables
    # @return [Boolean] True if partial has local variables
    def has_locals?
      !@local_variables.empty?
    end

    # Get local variable names
    # @return [Array<String>] Local variable names
    def local_names
      @local_variables.keys
    end

    # Get value for a local variable
    # @param name [String] Local variable name
    # @return [Object] Local variable value
    def local_value(name)
      @local_variables[name]
    end

    # Add parsed properties from the partial
    # @param properties [Array<BaseNode>] Properties from parsed partial
    # @return [Array<BaseNode>] Added properties
    def add_parsed_properties(properties)
      properties.each { |prop| add_child(prop) }
      properties
    end

    # Get all properties from the parsed partial
    # @return [Array<BaseNode>] Properties from partial
    def properties
      @children
    end

    # Convert to hash representation
    # @return [Hash] Hash representation
    def to_h
      super.merge(
        partial_path: @partial_path,
        property_name: @property_name,
        comment_data: @comment_data&.to_h,
        is_conditional: @is_conditional,
        required: required?,
        description: description,
        local_variables: @local_variables,
        properties: properties.map { |prop| prop.respond_to?(:to_h) ? prop.to_h : prop }
      ).compact
    end

    # Accept visitor for visitor pattern
    # @param visitor [Object] Visitor object
    # @return [Object] Result from visitor
    def accept(visitor)
      visitor.visit_partial(self)
    end
  end
end