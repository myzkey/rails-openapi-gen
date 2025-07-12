# frozen_string_literal: true

require_relative 'base_detector'

module RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
  # Detects JSON property calls (json.property_name)
  # Handles the most common Jbuilder pattern for setting properties
  class JsonCallDetector < BaseDetector
    # JSON methods that should not be treated as properties
    SPECIAL_METHODS = %w[array! partial! cache! cache_if! key_format! null! ignore_nil!].freeze

    class << self
      # Check if this detector handles the method call
      # @param receiver [Parser::AST::Node, nil] Method receiver node
      # @param method_name [Symbol] Method name
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Boolean] True if this is a JSON property call
      def handles?(receiver, method_name, args = [])
        json_property?(receiver, method_name)
      end

      # Higher priority since this is the most common case
      # @return [Integer] Priority value
      def priority
        10
      end

      # @return [Symbol] Detector category
      def category
        :property
      end

      # @return [String] Description
      def description
        "JSON property calls (json.property_name)"
      end

      # Checks if this is a json property call (json.property_name)
      # @param receiver [Parser::AST::Node, nil] The receiver of the method call
      # @param method_name [Symbol] The method name being called
      # @return [Boolean] True if this is a json property call
      def json_property?(receiver, method_name)
        return false if method_name.nil?
        return false if SPECIAL_METHODS.include?(method_name.to_s)
        
        # Don't handle bare "json" calls - these are receivers, not properties
        return false if receiver.nil? && method_name == :json
        
        # Must be called on json (implicit or explicit)
        json_receiver?(receiver)
      end

      # Checks if this is an array-related call (json.array!)
      # @param receiver [Parser::AST::Node, nil] The receiver of the method call
      # @param method_name [Symbol] The method name being called
      # @return [Boolean] True if this is an array call
      def array_call?(receiver, method_name)
        method_name == :array! && json_receiver?(receiver)
      end

      # Checks if this is a partial call (json.partial!)
      # @param receiver [Parser::AST::Node, nil] The receiver of the method call
      # @param method_name [Symbol] The method name being called
      # @return [Boolean] True if this is a partial call
      def partial_call?(receiver, method_name)
        method_name == :partial! && json_receiver?(receiver)
      end

      # Check if method call represents a simple property assignment
      # @param receiver [Parser::AST::Node, nil] Method receiver
      # @param method_name [Symbol] Method name
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Boolean] True if this is a simple property assignment
      def simple_property?(receiver, method_name, args)
        return false unless json_property?(receiver, method_name)
        
        # Simple property has exactly one argument and no block
        args.length == 1
      end

      # Check if method call represents a property with block (object)
      # @param receiver [Parser::AST::Node, nil] Method receiver
      # @param method_name [Symbol] Method name
      # @param has_block [Boolean] Whether the call has a block
      # @return [Boolean] True if this is a property with block
      def property_with_block?(receiver, method_name, has_block)
        json_property?(receiver, method_name) && has_block
      end
    end
  end
end