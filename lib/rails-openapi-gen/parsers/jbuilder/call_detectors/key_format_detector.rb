# frozen_string_literal: true

module RailsOpenapiGen
  module Parsers
    module Jbuilder
      module CallDetectors
        class KeyFormatDetector
          class << self
            # Detects if node represents a key formatting method
            # @param receiver [Parser::AST::Node] Receiver node
            # @param method_name [Symbol] Method name
            # @return [Boolean] True if key format method
            def key_format?(receiver, method_name)
              return false unless json_receiver?(receiver)
              
              key_format_methods = [:key_format!, :deep_format_keys!]
              key_format_methods.include?(method_name)
            end

            private

            # Checks if receiver is a json object
            # @param receiver [Parser::AST::Node] Receiver node
            # @return [Boolean] True if json receiver
            def json_receiver?(receiver)
              receiver && receiver.type == :send && receiver.children[1] == :json
            end
          end
        end
      end
    end
  end
end