# frozen_string_literal: true

module RailsOpenapiGen::AstNodes
    # Represents comment data parsed from @openapi annotations
    class CommentData
      attr_reader :type, :description, :required, :enum, :field_name, :items, :conditional

      def initialize(
        type: nil,
        description: nil, 
        required: true,
        enum: nil,
        field_name: nil,
        items: nil,
        conditional: false
      )
        @type = type
        @description = description
        @required = required
        @enum = enum
        @field_name = field_name
        @items = items
        @conditional = conditional
      end

      def required?
        @required != false && @required != 'false'
      end

      def optional?
        !required?
      end

      def to_h
        {
          type: @type,
          description: @description,
          required: @required,
          enum: @enum,
          field_name: @field_name,
          items: @items,
          conditional: @conditional
        }.compact
      end
    end

    # Base class for all property nodes
    class PropertyNode
      attr_reader :property, :comment_data, :is_conditional

      def initialize(property:, comment_data: nil, is_conditional: false)
        @property = property
        @comment_data = comment_data || CommentData.new
        @is_conditional = is_conditional
      end

      def required?
        @comment_data.required? && !@is_conditional
      end

      def optional?
        !required?
      end

      def to_h
        {
          property: @property,
          comment_data: @comment_data.to_h,
          is_conditional: @is_conditional
        }
      end
    end

    # Represents a simple property (string, integer, etc.)
    class SimplePropertyNode < PropertyNode
      def initialize(property:, comment_data: nil, is_conditional: false)
        super(property: property, comment_data: comment_data, is_conditional: is_conditional)
      end

      def to_h
        super.merge(
          node_type: :simple
        )
      end
    end

    # Represents an array property
    class ArrayPropertyNode < PropertyNode
      attr_reader :array_item_properties

      def initialize(property:, comment_data: nil, is_conditional: false, array_item_properties: [])
        super(property: property, comment_data: comment_data, is_conditional: is_conditional)
        @array_item_properties = array_item_properties
      end

      def add_item_property(property_node)
        @array_item_properties << property_node
      end

      def to_h
        super.merge(
          node_type: :array,
          is_array: true,
          array_item_properties: @array_item_properties.map(&:to_h)
        )
      end
    end

    # Represents an object property with nested properties
    class ObjectPropertyNode < PropertyNode
      attr_reader :nested_properties

      def initialize(property:, comment_data: nil, is_conditional: false, nested_properties: [])
        super(property: property, comment_data: comment_data, is_conditional: is_conditional)
        @nested_properties = nested_properties
      end

      def add_nested_property(property_node)
        @nested_properties << property_node
      end

      def to_h
        super.merge(
          node_type: :object,
          is_object: true,
          nested_properties: @nested_properties.map(&:to_h)
        )
      end
    end

    # Represents an array root (json.array! at top level)
    class ArrayRootNode < PropertyNode
      attr_reader :array_item_properties

      def initialize(comment_data: nil, array_item_properties: [])
        super(property: 'items', comment_data: comment_data, is_conditional: false)
        @array_item_properties = array_item_properties
      end

      def add_item_property(property_node)
        @array_item_properties << property_node
      end

      def to_h
        super.merge(
          node_type: :array_root,
          is_array_root: true,
          array_item_properties: @array_item_properties.map(&:to_h)
        )
      end
    end

    # Factory class for creating property nodes
    class PropertyNodeFactory
      class << self
        # Creates a property node from hash data (for backward compatibility)
        def from_hash(hash_data)
          # Handle both hash and structured node input
          if hash_data.is_a?(Hash)
            comment_data = create_comment_data(hash_data[:comment_data])
          else
            # Already a structured node, return as-is
            return hash_data
          end
          
          if hash_data[:is_array_root]
            ArrayRootNode.new(
              comment_data: comment_data,
              array_item_properties: create_nested_properties(hash_data[:array_item_properties])
            )
          elsif hash_data[:is_array]
            ArrayPropertyNode.new(
              property: hash_data[:property],
              comment_data: comment_data,
              is_conditional: hash_data[:is_conditional] || false,
              array_item_properties: create_nested_properties(hash_data[:array_item_properties])
            )
          elsif hash_data[:is_object] || hash_data[:nested_properties]
            ObjectPropertyNode.new(
              property: hash_data[:property],
              comment_data: comment_data,
              is_conditional: hash_data[:is_conditional] || false,
              nested_properties: create_nested_properties(hash_data[:nested_properties])
            )
          else
            SimplePropertyNode.new(
              property: hash_data[:property],
              comment_data: comment_data,
              is_conditional: hash_data[:is_conditional] || false
            )
          end
        end

        # Creates a simple property node
        def create_simple(property:, comment_data: nil, is_conditional: false)
          SimplePropertyNode.new(
            property: property,
            comment_data: create_comment_data(comment_data),
            is_conditional: is_conditional
          )
        end

        # Creates an array property node
        def create_array(property:, comment_data: nil, is_conditional: false, array_item_properties: [])
          ArrayPropertyNode.new(
            property: property,
            comment_data: create_comment_data(comment_data),
            is_conditional: is_conditional,
            array_item_properties: array_item_properties
          )
        end

        # Creates an object property node
        def create_object(property:, comment_data: nil, is_conditional: false, nested_properties: [])
          ObjectPropertyNode.new(
            property: property,
            comment_data: create_comment_data(comment_data),
            is_conditional: is_conditional,
            nested_properties: nested_properties
          )
        end

        # Creates an array root node
        def create_array_root(comment_data: nil, array_item_properties: [])
          ArrayRootNode.new(
            comment_data: create_comment_data(comment_data),
            array_item_properties: array_item_properties
          )
        end

        private

        def create_comment_data(data)
          return CommentData.new if data.nil?
          return data if data.is_a?(CommentData)
          
          # Convert hash to CommentData
          CommentData.new(
            type: data[:type],
            description: data[:description],
            required: data[:required],
            enum: data[:enum],
            field_name: data[:field_name],
            items: data[:items],
            conditional: data[:conditional]
          )
        end

        def create_nested_properties(properties_data)
          return [] if properties_data.nil?
          
          properties_data.map do |prop_data|
            from_hash(prop_data)
          end
        end
      end
    end
end