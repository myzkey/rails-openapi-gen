# frozen_string_literal: true

module RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
  class JsonCallDetector
    class << self
      # Detects if node represents a json property call
      # @param receiver [Parser::AST::Node] Receiver node
      # @param method_name [Symbol] Method name
      # @return [Boolean] True if json property call
      def json_property?(receiver, method_name)
        receiver && receiver.type == :send && receiver.children[1] == :json
      end
    end
  end
end