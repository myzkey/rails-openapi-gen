# frozen_string_literal: true

module RailsOpenapiGen::AstNodes
  # Represents comment data parsed from @openapi annotations
  # Encapsulates all OpenAPI-related metadata extracted from comments
  class CommentData
    attr_reader :type, :description, :required, :enum, :field_name, :items, :conditional, :format, :example

    def initialize(
      type: nil,
      description: nil, 
      required: true,
      enum: nil,
      field_name: nil,
      items: nil,
      conditional: false,
      format: nil,
      example: nil
    )
      @type = type
      @description = description
      @required = required
      @enum = enum
      @field_name = field_name
      @items = items
      @conditional = conditional
      @format = format
      @example = example
    end

    # Check if the property is required
    # @return [Boolean] True if property is required
    def required?
      @required != false && @required != 'false'
    end

    # Check if the property is optional
    # @return [Boolean] True if property is optional
    def optional?
      !required?
    end

    # Check if the property is conditional
    # @return [Boolean] True if property is conditional
    def conditional?
      @conditional == true || @conditional == 'true'
    end

    # Check if the property has enum values
    # @return [Boolean] True if property has enum values
    def has_enum?
      @enum && !@enum.empty?
    end

    # Check if the property has a specific format
    # @return [Boolean] True if property has format specification
    def has_format?
      # Auto-detect format from invalid types that were converted
      return true if auto_format_from_invalid_type
      
      @format && !@format.empty?
    end

    # Check if the property has an example
    # @return [Boolean] True if property has example
    def has_example?
      @example
    end

    # Get OpenAPI type, defaulting to string if not specified
    # @return [String] OpenAPI type
    def openapi_type
      # Handle common invalid types and auto-correct them
      case @type
      when 'date-time', 'datetime'
        # date-time is not a valid OpenAPI type, should be string with format
        'string'
      when 'date'
        # date is not a valid OpenAPI type, should be string with format
        'string'
      when 'time'
        # time is not a valid OpenAPI type, should be string with format
        'string'
      else
        @type || 'string'
      end
    end

    # Get format for the property, including auto-detected formats
    # @return [String, nil] Format specification
    def format
      # Auto-detect format from invalid types that were converted
      auto_format = auto_format_from_invalid_type
      return auto_format if auto_format
      
      @format
    end

    # Get items specification for arrays
    # @return [Hash, nil] Items specification
    def array_items
      return nil unless @type == 'array'
      @items || { 'type' => 'object' }
    end

    # Convert to hash representation suitable for OpenAPI schema
    # @return [Hash] Hash representation
    def to_openapi_schema
      schema = { 'type' => openapi_type }
      schema['description'] = @description if @description
      schema['enum'] = @enum if has_enum?
      schema['format'] = format if has_format?
      schema['example'] = @example if has_example?
      schema['items'] = array_items if @type == 'array' && array_items
      schema
    end

    # Convert to hash representation for internal use
    # @return [Hash] Hash representation
    def to_h
      {
        type: @type,
        description: @description,
        required: @required,
        enum: @enum,
        field_name: @field_name,
        items: @items,
        conditional: @conditional,
        format: @format,
        example: @example
      }.compact
    end

    # Merge with another CommentData, giving precedence to non-nil values
    # @param other [CommentData] Other comment data to merge
    # @return [CommentData] New merged comment data
    def merge(other)
      return self unless other.is_a?(CommentData)

      CommentData.new(
        type: other.type || @type,
        description: other.description || @description,
        required: other.required.nil? ? @required : other.required,
        enum: other.enum || @enum,
        field_name: other.field_name || @field_name,
        items: other.items || @items,
        conditional: other.conditional.nil? ? @conditional : other.conditional,
        format: other.format || @format,
        example: other.example || @example
      )
    end

    # Create a copy with updated attributes
    # @param attributes [Hash] Attributes to update
    # @return [CommentData] New comment data with updated attributes
    def with(**attributes)
      CommentData.new(
        type: attributes.fetch(:type, @type),
        description: attributes.fetch(:description, @description),
        required: attributes.fetch(:required, @required),
        enum: attributes.fetch(:enum, @enum),
        field_name: attributes.fetch(:field_name, @field_name),
        items: attributes.fetch(:items, @items),
        conditional: attributes.fetch(:conditional, @conditional),
        format: attributes.fetch(:format, @format),
        example: attributes.fetch(:example, @example)
      )
    end

    private

    # Auto-detect format from invalid types that were converted to string
    # @return [String, nil] Format specification
    def auto_format_from_invalid_type
      case @type
      when 'date-time', 'datetime'
        'date-time'
      when 'date'
        'date'
      when 'time'
        'time'
      else
        nil
      end
    end
  end
end