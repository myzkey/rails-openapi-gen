# frozen_string_literal: true

require_relative 'base_detector'

module RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
  # Detects cache calls (json.cache!, json.cache_if!)
  # Handles caching directives in Jbuilder templates
  class CacheCallDetector < BaseDetector
    # Cache methods that this detector handles
    CACHE_METHODS = %w[cache! cache_if!].freeze

    class << self
      # Check if this detector handles the method call
      # @param receiver [Parser::AST::Node, nil] Method receiver node
      # @param method_name [Symbol] Method name
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Boolean] True if this is a cache call
      def handles?(receiver, method_name, _args = [])
        cache_call?(receiver, method_name) || cache_if_call?(receiver, method_name)
      end

      # Medium priority - caching doesn't affect schema structure
      # @return [Integer] Priority value
      def priority
        5
      end

      # @return [Symbol] Detector category
      def category
        :meta
      end

      # @return [String] Description
      def description
        "Cache calls (json.cache!, json.cache_if!)"
      end

      # Check if this is a cache call
      # @param receiver [Parser::AST::Node, nil] Method receiver
      # @param method_name [Symbol] Method name
      # @return [Boolean] True if this is a cache call
      def cache_call?(receiver, method_name)
        method_name == :cache! && json_receiver?(receiver)
      end

      # Check if this is a conditional cache call
      # @param receiver [Parser::AST::Node, nil] Method receiver
      # @param method_name [Symbol] Method name
      # @return [Boolean] True if this is a cache_if call
      def cache_if_call?(receiver, method_name)
        method_name == :cache_if! && json_receiver?(receiver)
      end

      # Check if method is any cache-related method
      # @param method_name [Symbol] Method name
      # @return [Boolean] True if method is cache-related
      def cache_method?(method_name)
        CACHE_METHODS.include?(method_name.to_s)
      end

      # Extract cache key from arguments
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [String, nil] Cache key
      def extract_cache_key(args)
        return nil if args.empty?

        first_arg = args.first
        extract_string_value(first_arg)
      end

      # Extract cache condition from cache_if! arguments
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Parser::AST::Node, nil] Condition node
      def extract_cache_condition(args)
        return nil if args.length < 2

        args.first # First argument is the condition
      end

      # Check if cache call has block
      # @param node [Parser::AST::Node] The cache call node
      # @return [Boolean] True if cache has block
      def has_block?(node)
        node.type == :block
      end

      # Extract cache options from arguments
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Hash] Cache options
      def extract_cache_options(args)
        options = {}

        args.each do |arg|
          next unless arg.type == :hash

          arg.children.each do |pair|
            next unless pair.type == :pair

            key_node, value_node = pair.children
            next unless key_node.type == :sym

            key = key_node.children.first
            value = extract_string_value(value_node) || value_node
            options[key] = value
          end
        end

        options
      end
    end
  end
end
