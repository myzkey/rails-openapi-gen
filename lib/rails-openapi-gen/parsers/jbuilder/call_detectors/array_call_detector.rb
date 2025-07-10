# frozen_string_literal: true

module RailsOpenapiGen
  module Parsers
    module Jbuilder
      module CallDetectors
        class ArrayCallDetector
          class << self
            # Detects if node represents a json.array! call
            # @param receiver [Parser::AST::Node] Receiver node
            # @param method_name [Symbol] Method name
            # @return [Boolean] True if array call
            def array_call?(receiver, method_name)
              method_name == :array! && receiver && receiver.type == :send && receiver.children[1] == :json
            end

            # Checks if hash node contains a :partial key
            # @param hash_node [Parser::AST::Node] Hash node to check
            # @return [Boolean] True if partial key exists
            def has_partial_key?(hash_node)
              hash_node.children.any? do |pair|
                if pair.type == :pair
                  key, _value = pair.children
                  key.type == :sym && key.children.first == :partial
                end
              end
            end
          end
        end
      end
    end
  end
end