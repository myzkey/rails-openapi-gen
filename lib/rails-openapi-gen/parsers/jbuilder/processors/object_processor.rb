# frozen_string_literal: true

require_relative 'base_processor'
require_relative '../call_detectors'

module RailsOpenapiGen::Parsers::Jbuilder::Processors
  class ObjectProcessor < BaseProcessor
          # Alias for shorter reference to call detectors
          CallDetectors = RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
          # Lazy load CompositeProcessor to avoid circular dependency
          def self.composite_processor_class
            RailsOpenapiGen::Parsers::Jbuilder::Processors::CompositeProcessor
          end
          # Processes block nodes for nested object blocks
          # @param node [Parser::AST::Node] Block node
          # @return [void]
          def on_block(node)
            send_node, args_node, = node.children
            receiver, method_name, = send_node.children

            if CallDetectors::JsonCallDetector.json_property?(receiver, method_name) && method_name != :array!
              # Check if this is a nested object block (no block arguments)
              if !args_node || args_node.type != :args || args_node.children.empty?
                # This is a nested object block like json.profile do
                process_nested_object_block(node, method_name.to_s)
              else
                super(node)
              end
            else
              super(node)
            end
          end

          private

          # Processes nested object blocks (e.g., json.profile do)
          # @param node [Parser::AST::Node] Block node
          # @param property_name [String] Object property name
          # @return [void]
          def process_nested_object_block(node, property_name)
            comment_data = find_comment_for_node(node)

            # Save current context
            previous_nested_objects = @nested_objects.dup
            previous_properties = properties.dup
            previous_partials = partials.dup

            # Create a temporary properties array for this nested object
            @properties = []
            @partials = []
            push_block(:object)

            # Process the block contents using CompositeProcessor
            _, _args, body = node.children
            if body
              # Create a CompositeProcessor to handle all types of calls within the block
              composite_processor = self.class.composite_processor_class.new(@file_path, @property_parser)
              composite_processor.process_node(body)

              # Merge results from the composite processor
              @properties.concat(composite_processor.properties)
              @partials.concat(composite_processor.partials)
            end

            # Collect nested properties from direct block processing
            nested_properties = properties.dup

            # Process any partials found in this block
            partials.each do |partial_path|
              if File.exist?(partial_path)
                partial_properties = parse_partial_for_nested_object(partial_path)
                nested_properties.concat(partial_properties)
              end
            end

            # Check if this object block contains only a json.array! call
            # In that case, we should treat this as a direct array instead of an object
            has_only_array_root = nested_properties.size == 1 && is_array_root_property(nested_properties.first)

            # Restore context but keep partials for higher level processing
            @properties = previous_properties
            @partials = previous_partials
            @nested_objects = previous_nested_objects
            pop_block

            if has_only_array_root
              # This is a json.property do + json.array! pattern
              # Treat the property as a direct array instead of an object with items
              array_root_node = nested_properties.first
              
              # Create comment data
              comment_obj = if comment_data
                RailsOpenapiGen::AstNodes::CommentData.new(
                  type: comment_data[:type] || 'array',
                  items: comment_data[:items] || { type: 'object' }
                )
              else
                RailsOpenapiGen::AstNodes::CommentData.new(type: 'array', items: { type: 'object' })
              end

              # Create array property node
              array_item_properties = get_array_item_properties(array_root_node)
              property_node = RailsOpenapiGen::AstNodes::PropertyNodeFactory.create_array(
                property: property_name,
                comment_data: comment_obj,
                array_item_properties: array_item_properties
              )
            else
              # Store nested object info
              @nested_objects[property_name] = nested_properties

              # Create comment data
              comment_obj = if comment_data
                RailsOpenapiGen::AstNodes::CommentData.new(
                  type: comment_data[:type] || 'object'
                )
              else
                RailsOpenapiGen::AstNodes::CommentData.new(type: 'object')
              end

              # Add the parent property as a regular object
              property_node = RailsOpenapiGen::AstNodes::PropertyNodeFactory.create_object(
                property: property_name,
                comment_data: comment_obj,
                nested_properties: nested_properties
              )
            end

            add_property(property_node)
          end

          # Helper methods for structured AST support

          # Checks if a property is an array root property
          # @param property [PropertyNode, Hash] Property to check
          # @return [Boolean] True if it's an array root property
          def is_array_root_property(property)
            if property.is_a?(Hash)
              (property[:is_array_root] || property[:is_array]) &&
              (property[:property] == 'items' || property[:is_array])
            else
              property.is_a?(RailsOpenapiGen::AstNodes::ArrayRootNode) ||
              (property.is_a?(RailsOpenapiGen::AstNodes::ArrayPropertyNode) && property.property == 'items')
            end
          end

          # Gets array item properties from an array root node
          # @param array_node [PropertyNode, Hash] Array root node
          # @return [Array] Array of item properties
          def get_array_item_properties(array_node)
            if array_node.is_a?(Hash)
              array_node[:array_item_properties] || []
            else
              array_node.array_item_properties || []
            end
          end
  end
end
