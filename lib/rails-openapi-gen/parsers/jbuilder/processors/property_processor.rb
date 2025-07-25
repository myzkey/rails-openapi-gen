# frozen_string_literal: true

require_relative 'base_processor'
require_relative '../call_detectors'

module RailsOpenapiGen::Parsers::Jbuilder::Processors
  class PropertyProcessor < BaseProcessor
    # Alias for shorter reference to call detectors
    CallDetectors = RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
    # Processes method call nodes for simple property assignments
    # @param node [Parser::AST::Node] Method call node
    # @return [void]
    def on_send(node)
      receiver, method_name, *args = node.children

      if CallDetectors::JsonCallDetector.json_property?(receiver, method_name)
        process_json_property(node, method_name.to_s, args)
      else
        # For non-JSON property calls, don't process anything to avoid creating
        # properties for variable access calls
        super
      end
    end

    private

    # Processes a simple JSON property assignment
    # @param node [Parser::AST::Node] Property node
    # @param property_name [String] Name of the property
    # @param args [Array] Method arguments
    # @return [void]
    def process_json_property(node, property_name, _args)
      comment_data = find_comment_for_node(node)

      # Process simple property regardless of context
      # Note: In the future, different processing could be added based on context
      process_simple_property(node, property_name, comment_data)
    end

    # Processes a simple property assignment
    # @param node [Parser::AST::Node] Property node
    # @param property_name [String] Name of the property
    # @param comment_data [Hash, nil] Parsed comment data
    # @return [void]
    def process_simple_property(_node, property_name, comment_data)
      # Create comment data object
      comment_obj = if comment_data && !comment_data.empty?
                      RailsOpenapiGen::AstNodes::CommentData.new(
                        type: comment_data[:type],
                        description: comment_data[:description],
                        required: comment_data[:required],
                        enum: comment_data[:enum],
                        field_name: comment_data[:field_name]
                      )
                    else
                      RailsOpenapiGen::AstNodes::CommentData.new(type: 'TODO: MISSING COMMENT')
                    end

      # Create simple property node
      property_node = RailsOpenapiGen::AstNodes::PropertyNodeFactory.create_simple(
        property: property_name,
        comment_data: comment_obj
      )

      add_property(property_node)
    end
  end
end
