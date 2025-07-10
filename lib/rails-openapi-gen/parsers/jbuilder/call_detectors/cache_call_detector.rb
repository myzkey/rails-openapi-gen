# frozen_string_literal: true

module RailsOpenapiGen
  module Parsers
    module Jbuilder
      module CallDetectors
        class CacheCallDetector
          class << self
            # Detects if node represents a json.cache! call
            # @param receiver [Parser::AST::Node] Receiver node
            # @param method_name [Symbol] Method name
            # @return [Boolean] True if cache call
            def cache_call?(receiver, method_name)
              method_name == :cache! && receiver && receiver.type == :send && receiver.children[1] == :json
            end

            # Detects if node represents a json.cache_if! call
            # @param receiver [Parser::AST::Node] Receiver node
            # @param method_name [Symbol] Method name
            # @return [Boolean] True if cache_if call
            def cache_if_call?(receiver, method_name)
              method_name == :cache_if! && receiver && receiver.type == :send && receiver.children[1] == :json
            end
          end
        end
      end
    end
  end
end