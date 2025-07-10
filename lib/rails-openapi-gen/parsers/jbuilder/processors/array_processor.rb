# frozen_string_literal: true

require_relative "base_processor"
require_relative "../call_detectors/array_call_detector"
require_relative "../call_detectors/json_call_detector"

module RailsOpenapiGen
  module Parsers
    module Jbuilder
      module Processors
      class ArrayProcessor < BaseProcessor
        # Processes method call nodes for array-related operations
        # @param node [Parser::AST::Node] Method call node
        # @return [void]
        def on_send(node)
          receiver, method_name, *args = node.children
          
          if Jbuilder::CallDetectors::ArrayCallDetector.array_call?(receiver, method_name)
            # Check if this is an array with partial
            if args.any? && args.any? { |arg| arg.type == :hash && Jbuilder::CallDetectors::ArrayCallDetector.has_partial_key?(arg) }
              process_array_with_partial(node, args)
            else
              process_array_property(node)
            end
          end
          
          super
        end

        # Processes block nodes for array iterations
        # @param node [Parser::AST::Node] Block node
        # @return [void]
        def on_block(node)
          send_node, args_node, body = node.children
          receiver, method_name, *send_args = send_node.children
          
          if Jbuilder::CallDetectors::ArrayCallDetector.array_call?(receiver, method_name)
            # This is json.array! block
            push_block(:array)
            super
            pop_block
          elsif Jbuilder::CallDetectors::JsonCallDetector.json_property?(receiver, method_name) && method_name != :array!
            # Check if this is an array iteration block (has block arguments)
            if args_node && args_node.type == :args && args_node.children.any?
              # This is an array iteration block like json.tags @tags do |tag|
              process_array_iteration_block(node, method_name.to_s)
            else
              super
            end
          else
            super
          end
        end

        private

        # Processes json.array! calls to create array schema
        # @param node [Parser::AST::Node] Array call node
        # @return [void]
        def process_array_property(node)
          comment_data = find_comment_for_node(node)
          
          # Mark this as an array root
          property_info = {
            property: "items", # Special property to indicate array items
            comment_data: comment_data || { type: "array", items: { type: "object" } },
            is_array_root: true
          }
          
          add_property(property_info)
        end
        
        # Processes json.array! with partial rendering
        # @param node [Parser::AST::Node] Array call node
        # @param args [Array] Array call arguments
        # @return [void]
        def process_array_with_partial(node, args)
          # Extract partial path from the hash arguments
          partial_path = nil
          args.each do |arg|
            if arg.type == :hash
              arg.children.each do |pair|
                if pair.type == :pair
                  key, value = pair.children
                  if key.type == :sym && key.children.first == :partial && value.type == :str
                    partial_path = value.children.first
                    break
                  end
                end
              end
            end
          end
          
          if partial_path
            # Resolve the partial path and parse it
            resolved_path = resolve_partial_path(partial_path)
            if resolved_path && File.exist?(resolved_path)
              # Parse the partial to get its properties
              partial_parser = RailsOpenapiGen::Parsers::Jbuilder::JbuilderParser.new(resolved_path)
              partial_result = partial_parser.parse
              
              # Create array schema with items from the partial
              property_info = {
                property: "items",
                comment_data: { type: "array" },
                is_array_root: true,
                array_item_properties: partial_result[:properties]
              }
              
              add_property(property_info)
            else
              # Fallback to regular array processing
              process_array_property(node)
            end
          else
            # Fallback to regular array processing
            process_array_property(node)
          end
        end

        # Processes array iteration blocks (e.g., json.tags @tags do |tag|)
        # @param node [Parser::AST::Node] Block node
        # @param property_name [String] Array property name
        # @return [void]
        def process_array_iteration_block(node, property_name)
          comment_data = find_comment_for_node(node)
          
          # Save current context
          previous_properties = @properties.dup
          previous_partials = @partials.dup
          
          # Create a temporary properties array for array items
          @properties = []
          @partials = []
          push_block(:array)
          
          # Process the block contents
          send_node, _args, body = node.children
          process(body) if body
          
          # Collect item properties
          item_properties = @properties.dup
          
          # Process any partials found in this block
          @partials.each do |partial_path|
            if File.exist?(partial_path)
              partial_properties = parse_partial_for_nested_object(partial_path)
              item_properties.concat(partial_properties)
            end
          end
          
          # Restore context
          @properties = previous_properties
          @partials = previous_partials
          pop_block
          
          # Build array schema with items
          property_info = {
            property: property_name,
            comment_data: comment_data || { type: "array" },
            is_array: true,
            array_item_properties: item_properties
          }
          
          add_property(property_info)
        end
        end
      end
    end
  end
end