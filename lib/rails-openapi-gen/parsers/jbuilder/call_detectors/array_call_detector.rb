# frozen_string_literal: true

require_relative 'base_detector'

module RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
  # Detects array calls (json.array!)
  # Handles array generation in Jbuilder templates
  class ArrayCallDetector < BaseDetector
    class << self
      # Check if this detector handles the method call
      # @param receiver [Parser::AST::Node, nil] Method receiver node
      # @param method_name [Symbol] Method name
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Boolean] True if this is an array call
      def handles?(receiver, method_name, args = [])
        result = array_call?(receiver, method_name)
        if ENV['RAILS_OPENAPI_DEBUG']
          puts "🔍 DEBUG: ArrayCallDetector.handles? for #{method_name}"
          puts "   receiver: #{receiver.inspect}"
          puts "   method_name: #{method_name.inspect}"
          puts "   method_name == :array!: #{method_name == :array!}"
          puts "   json_receiver?: #{json_receiver?(receiver)}"
          puts "   result: #{result}"
        end
        result
      end

      # High priority for array calls
      # @return [Integer] Priority value
      def priority
        20
      end

      # @return [Symbol] Detector category
      def category
        :array
      end

      # @return [String] Description
      def description
        "Array calls (json.array!)"
      end

      # Check if this is an array call
      # @param receiver [Parser::AST::Node, nil] Method receiver
      # @param method_name [Symbol] Method name
      # @return [Boolean] True if this is an array call
      def array_call?(receiver, method_name)
        method_name == :array! && json_receiver?(receiver)
      end

      # Check if arguments contain partial key in hash
      # @param hash_node [Parser::AST::Node] Hash node to check
      # @return [Boolean] True if hash contains partial key
      def has_partial_key?(hash_node)
        return false unless hash_node.type == :hash
        
        hash_node.children.any? do |pair|
          next false unless pair.type == :pair
          
          key, _value = pair.children
          key.type == :sym && key.children.first == :partial
        end
      end

      # Check if array call has collection argument
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Boolean] True if array has collection
      def has_collection?(args)
        args.any? && !args.first.type == :hash
      end

      # Check if array call has options hash
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Boolean] True if array has options
      def has_options?(args)
        args.any? { |arg| arg.type == :hash }
      end

      # Extract collection from array arguments
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Parser::AST::Node, nil] Collection node
      def extract_collection(args)
        args.find { |arg| arg.type != :hash }
      end

      # Extract options hash from array arguments
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Parser::AST::Node, nil] Options hash node
      def extract_options(args)
        args.find { |arg| arg.type == :hash }
      end

      # Check if array call uses partial rendering
      # @param args [Array<Parser::AST::Node>] Method arguments
      # @return [Boolean] True if array uses partial
      def uses_partial?(args)
        options = extract_options(args)
        options && has_partial_key?(options)
      end
    end
  end
end
