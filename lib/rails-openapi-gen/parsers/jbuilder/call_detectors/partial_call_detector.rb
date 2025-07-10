# frozen_string_literal: true

module RailsOpenapiGen
  module Parsers
    module Jbuilder
      module CallDetectors
        class PartialCallDetector
          class << self
            # Detects if node represents a partial render call
            # @param receiver [Parser::AST::Node] Receiver node
            # @param method_name [Symbol] Method name
            # @return [Boolean] True if partial call
            def partial_call?(receiver, method_name)
              method_name == :partial! && (!receiver || receiver.type == :send && receiver.children[1] == :json)
            end
          end
        end
      end
    end
  end
end