# frozen_string_literal: true

require_relative "base_processor"
require_relative "../call_detectors/json_call_detector"

module RailsOpenapiGen
  module Parsers
    module Jbuilder
      module Processors
        class PropertyProcessor < BaseProcessor
          # Processes method call nodes for simple property assignments
          # @param node [Parser::AST::Node] Method call node
          # @return [void]
          def on_send(node)
            receiver, method_name, *args = node.children
            
            if Jbuilder::CallDetectors::JsonCallDetector.json_property?(receiver, method_name)
              process_json_property(node, method_name.to_s, args)
            end
            
            super
          end

          private

          # Processes a simple JSON property assignment
          # @param node [Parser::AST::Node] Property node
          # @param property_name [String] Name of the property
          # @param args [Array] Method arguments
          # @return [void]
          def process_json_property(node, property_name, args)
            comment_data = find_comment_for_node(node)
            
            # Check if we're inside an array block
            if inside_block?(:array)
              process_simple_property(node, property_name, comment_data)
            else
              process_simple_property(node, property_name, comment_data)
            end
          end

          # Processes a simple property assignment
          # @param node [Parser::AST::Node] Property node
          # @param property_name [String] Name of the property
          # @param comment_data [Hash, nil] Parsed comment data
          # @return [void]
          def process_simple_property(node, property_name, comment_data)
            property_info = {
              property: property_name,
              comment_data: comment_data
            }
            
            unless comment_data && !comment_data.empty?
              property_info[:comment_data] = { type: "TODO: MISSING COMMENT" }
            end
            
            add_property(property_info)
          end
        end
      end
    end
  end
end