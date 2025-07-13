# frozen_string_literal: true

require_relative 'base_detector'

module RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
  # Detects partial calls (json.partial!)
  # Handles partial template rendering in Jbuilder
  class PartialCallDetector < BaseDetector
    class << self
      # Check if this detector handles the method call
      # @param receiver [Parser::AST::Node, nil] Method receiver node
      # @param method_name [Symbol] Method name
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Boolean] True if this is a partial call
      def handles?(receiver, method_name, _args = [])
        partial_call?(receiver, method_name)
      end

      # High priority for partial calls
      # @return [Integer] Priority value
      def priority
        20
      end

      # @return [Symbol] Detector category
      def category
        :partial
      end

      # @return [String] Description
      def description
        "Partial calls (json.partial!)"
      end

      # Check if this is a partial call
      # @param receiver [Parser::AST::Node, nil] Method receiver
      # @param method_name [Symbol] Method name
      # @return [Boolean] True if this is a partial call
      def partial_call?(receiver, method_name)
        method_name == :partial! && json_receiver?(receiver)
      end

      # Extract partial path from arguments
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [String, nil] Partial path
      def extract_partial_path(args)
        return nil if args.empty?

        first_arg = args.first
        return extract_string_value(first_arg) if literal_node?(first_arg)

        # Check if it's in a hash under :partial key
        if first_arg.type == :hash
          partial_pair = first_arg.children.find do |pair|
            key_node = pair.children.first
            key_node.type == :sym && key_node.children.first == :partial
          end

          if partial_pair
            value_node = partial_pair.children.last
            return extract_string_value(value_node)
          end
        end

        nil
      end

      # Extract local variables from arguments
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Hash] Local variables hash
      def extract_locals(args)
        locals = {}

        args.each do |arg|
          next unless arg.type == :hash

          arg.children.each do |pair|
            next unless pair.type == :pair

            key_node, value_node = pair.children
            next unless key_node.type == :sym

            key = key_node.children.first
            next if key == :partial # Skip partial path

            # For now, just store the key, value extraction would need evaluation
            locals[key] = value_node
          end
        end

        locals
      end

      # Check if partial has locals
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Boolean] True if partial has locals
      def has_locals?(args)
        !extract_locals(args).empty?
      end

      # Check if partial path is a string literal
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Boolean] True if path is literal
      def literal_path?(args)
        return false if args.empty?

        literal_node?(args.first)
      end

      # Check if partial is called with collection
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Boolean] True if partial has collection
      def has_collection?(args)
        args.any? do |arg|
          next false unless arg.type == :hash

          arg.children.any? do |pair|
            key_node = pair.children.first
            key_node.type == :sym && key_node.children.first == :collection
          end
        end
      end
    end
  end
end
