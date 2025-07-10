# frozen_string_literal: true

require_relative "base_processor"
require_relative "../call_detectors/json_call_detector"

module RailsOpenapiGen
  module Parsers
    module Jbuilder
      module Processors
        class ObjectProcessor < BaseProcessor
          # Processes block nodes for nested object blocks
          # @param node [Parser::AST::Node] Block node
          # @return [void]
          def on_block(node)
            send_node, args_node, body = node.children
            receiver, method_name, *send_args = send_node.children
            
            if Jbuilder::CallDetectors::JsonCallDetector.json_property?(receiver, method_name) && method_name != :array!
              # Check if this is a nested object block (no block arguments)
              if !args_node || args_node.type != :args || args_node.children.empty?
                # This is a nested object block like json.profile do
                process_nested_object_block(node, method_name.to_s)
              else
                super
              end
            else
              super
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
            previous_properties = @properties.dup
            previous_partials = @partials.dup
            
            # Create a temporary properties array for this nested object
            @properties = []
            @partials = []
            push_block(:object)
            
            # Process the block contents
            send_node, _args, body = node.children
            process(body) if body
            
            # Collect nested properties
            nested_properties = @properties.dup
            
            # Process any partials found in this block
            @partials.each do |partial_path|
              if File.exist?(partial_path)
                partial_properties = parse_partial_for_nested_object(partial_path)
                nested_properties.concat(partial_properties)
              end
            end
            
            # Restore context
            @properties = previous_properties
            @partials = previous_partials # Don't add nested partials to main partials
            @nested_objects = previous_nested_objects
            pop_block
            
            # Store nested object info
            @nested_objects[property_name] = nested_properties
            
            # Add the parent property
            property_info = {
              property: property_name,
              comment_data: comment_data || { type: "object" },
              is_object: true,
              nested_properties: nested_properties
            }
            
            add_property(property_info)
          end
        end
      end
    end
  end
end