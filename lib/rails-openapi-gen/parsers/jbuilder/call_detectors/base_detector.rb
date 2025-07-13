# frozen_string_literal: true

module RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
  # Base class for all call detectors
  # Provides common interface and utility methods for detecting Jbuilder method calls
  class BaseDetector
    class << self
      # Check if a method call matches this detector's patterns
      # @param receiver [Parser::AST::Node, nil] Method receiver node
      # @param method_name [Symbol] Method name
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Boolean] True if this detector handles the method call
      def handles?(_receiver, _method_name, _args = [])
        raise NotImplementedError, "#{self} must implement #handles?"
      end

      # Get the detection priority for this detector
      # Higher priority detectors are checked first
      # @return [Integer] Priority value (higher = more priority)
      def priority
        0
      end

      # Get the category of this detector for organization
      # @return [Symbol] Detector category
      def category
        :general
      end

      # Get human-readable description of what this detector handles
      # @return [String] Description
      def description
        "Base detector"
      end

      protected

      # Check if receiver is json object
      # @param receiver [Parser::AST::Node, nil] Receiver node
      # @return [Boolean] True if receiver is json
      def json_receiver?(receiver)
        # Handle implicit json calls (receiver is nil in top-level context)
        return true if receiver.nil?

        # Handle explicit json calls (json.property_name)
        return true if receiver.type == :send && receiver.children[0].nil? && receiver.children[1] == :json

        false
      end

      # Check if method name matches any of the given patterns
      # @param method_name [Symbol, String] Method name to check
      # @param patterns [Array<Symbol, String, Regexp>] Patterns to match against
      # @return [Boolean] True if method name matches any pattern
      def method_matches?(method_name, patterns)
        patterns.any? do |pattern|
          case pattern
          when Symbol, String
            method_name.to_sym == pattern.to_sym
          when Regexp
            pattern.match?(method_name.to_s)
          else
            false
          end
        end
      end

      # Check if arguments contain a hash with specific keys
      # @param args [Array<Parser::AST::Node>] Arguments to check
      # @param keys [Array<Symbol>] Keys to look for
      # @return [Boolean] True if hash argument contains any of the keys
      def args_contain_hash_with_keys?(args, keys)
        args.any? do |arg|
          next false unless arg.type == :hash

          hash_keys = arg.children.map do |pair|
            key_node = pair.children.first
            key_node.type == :sym ? key_node.children.first : nil
          end.compact

          (keys & hash_keys).any?
        end
      end

      # Extract string value from a node
      # @param node [Parser::AST::Node] Node to extract value from
      # @return [String, nil] String value or nil
      def extract_string_value(node)
        return nil unless node

        case node.type
        when :str
          node.children.first
        when :sym
          node.children.first.to_s
        end
      end

      # Check if node represents a literal value
      # @param node [Parser::AST::Node] Node to check
      # @return [Boolean] True if node is a literal
      def literal_node?(node)
        %i[str int float true false nil sym].include?(node.type)
      end
    end
  end
end
