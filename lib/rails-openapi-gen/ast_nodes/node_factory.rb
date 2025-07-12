# frozen_string_literal: true

module RailsOpenapiGen::AstNodes
  # Factory class for creating AST nodes
  # Provides convenient methods for creating different types of nodes
  class NodeFactory
    class << self
      # Create a property node
      # @param property_name [String] Name of the property
      # @param comment_data [CommentData, Hash, nil] Comment data
      # @param is_conditional [Boolean] Whether property is conditional
      # @param parent [BaseNode, nil] Parent node
      # @return [PropertyNode] Created property node
      def create_property(property_name:, comment_data: nil, is_conditional: false, parent: nil)
        PropertyNode.new(
          property_name: property_name,
          comment_data: normalize_comment_data(comment_data),
          is_conditional: is_conditional,
          parent: parent
        )
      end

      # Create an array node
      # @param property_name [String, nil] Name of the array property
      # @param comment_data [CommentData, Hash, nil] Comment data
      # @param is_conditional [Boolean] Whether array is conditional
      # @param is_root_array [Boolean] Whether this is a root array (json.array!)
      # @param parent [BaseNode, nil] Parent node
      # @return [ArrayNode] Created array node
      def create_array(property_name: nil, comment_data: nil, is_conditional: false, is_root_array: false, parent: nil)
        ArrayNode.new(
          property_name: property_name,
          comment_data: normalize_comment_data(comment_data, default_type: 'array'),
          is_conditional: is_conditional,
          is_root_array: is_root_array,
          parent: parent
        )
      end

      # Create an object node
      # @param property_name [String] Name of the object property
      # @param comment_data [CommentData, Hash, nil] Comment data
      # @param is_conditional [Boolean] Whether object is conditional
      # @param parent [BaseNode, nil] Parent node
      # @return [ObjectNode] Created object node
      def create_object(property_name:, comment_data: nil, is_conditional: false, parent: nil)
        ObjectNode.new(
          property_name: property_name,
          comment_data: normalize_comment_data(comment_data, default_type: 'object'),
          is_conditional: is_conditional,
          parent: parent
        )
      end

      # Create a partial node
      # @param partial_path [String] Path to the partial
      # @param property_name [String, nil] Name of the property (for nested partials)
      # @param comment_data [CommentData, Hash, nil] Comment data
      # @param is_conditional [Boolean] Whether partial is conditional
      # @param local_variables [Hash] Local variables passed to partial
      # @param parent [BaseNode, nil] Parent node
      # @return [PartialNode] Created partial node
      def create_partial(partial_path:, property_name: nil, comment_data: nil, is_conditional: false, local_variables: {}, parent: nil)
        PartialNode.new(
          partial_path: partial_path,
          property_name: property_name,
          comment_data: normalize_comment_data(comment_data),
          is_conditional: is_conditional,
          local_variables: local_variables,
          parent: parent
        )
      end

      # Create a node from hash data (backward compatibility)
      # @param hash_data [Hash] Hash containing node data
      # @return [BaseNode] Created node
      def from_hash(hash_data)
        return hash_data unless hash_data.is_a?(Hash)

        case hash_data[:node_type]&.to_sym
        when :array
          create_array(
            property_name: hash_data[:property_name] || hash_data[:property],
            comment_data: hash_data[:comment_data],
            is_conditional: hash_data[:is_conditional] || false,
            is_root_array: hash_data[:is_root_array] || hash_data[:is_array_root] || false
          )
        when :object
          create_object(
            property_name: hash_data[:property_name] || hash_data[:property],
            comment_data: hash_data[:comment_data],
            is_conditional: hash_data[:is_conditional] || false
          )
        when :partial
          create_partial(
            partial_path: hash_data[:partial_path],
            property_name: hash_data[:property_name] || hash_data[:property],
            comment_data: hash_data[:comment_data],
            is_conditional: hash_data[:is_conditional] || false,
            local_variables: hash_data[:local_variables] || {}
          )
        else
          # Check if this is an array property that should be preserved as hash
          if hash_data[:is_array] && hash_data[:array_item_properties]
            # Return hash data directly to preserve array information
            hash_data
          else
            create_property(
              property_name: hash_data[:property_name] || hash_data[:property],
              comment_data: hash_data[:comment_data],
              is_conditional: hash_data[:is_conditional] || false
            )
          end
        end
      end

      # Create nodes from an array of hash data
      # @param hash_array [Array<Hash>] Array of hash data
      # @return [Array<BaseNode>] Array of created nodes
      def from_hash_array(hash_array)
        return [] unless hash_array.is_a?(Array)

        hash_array.map { |hash_data| from_hash(hash_data) }
      end

      # Create a tree structure from nested hash data
      # @param hash_data [Hash] Root hash data
      # @return [BaseNode] Root node with children
      def create_tree(hash_data)
        root_node = from_hash(hash_data)

        # Add children if present
        if hash_data[:children]
          hash_data[:children].each do |child_data|
            child_node = create_tree(child_data)
            root_node.add_child(child_node)
          end
        end

        # Add specific child types
        add_specific_children(root_node, hash_data)

        root_node
      end

      private

      # Normalize comment data to CommentData instance
      # @param data [CommentData, Hash, nil] Comment data input
      # @param default_type [String, nil] Default type if not specified
      # @return [CommentData] Normalized comment data
      def normalize_comment_data(data, default_type: nil)
        return CommentData.new(type: default_type) if data.nil?
        return data if data.is_a?(CommentData)

        # Convert hash to CommentData
        CommentData.new(
          type: data[:type] || default_type,
          description: data[:description],
          required: data[:required],
          enum: data[:enum],
          field_name: data[:field_name],
          items: data[:items],
          conditional: data[:conditional],
          format: data[:format],
          example: data[:example]
        )
      end

      # Add specific children based on node type
      # @param node [BaseNode] Parent node
      # @param hash_data [Hash] Hash data containing children
      # @return [void]
      def add_specific_children(node, hash_data)
        case node
        when ArrayNode
          # Add array items
          if hash_data[:items]
            hash_data[:items].each do |item_data|
              item_node = from_hash(item_data)
              node.add_item(item_node)
            end
          end
        when ObjectNode
          # Add object properties
          if hash_data[:properties]
            hash_data[:properties].each do |prop_data|
              prop_node = from_hash(prop_data)
              node.add_property(prop_node)
            end
          end
        when PartialNode
          # Add parsed properties
          if hash_data[:properties]
            properties = from_hash_array(hash_data[:properties])
            node.add_parsed_properties(properties)
          end
        end
      end
    end
  end
end