# frozen_string_literal: true

module RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
  class NullHandlingDetector
    class << self
      # Detects if node represents a null/nil handling method
      # @param receiver [Parser::AST::Node] Receiver node
      # @param method_name [Symbol] Method name
      # @return [Boolean] True if null handling method
      def null_handling?(receiver, method_name)
        return false unless json_receiver?(receiver)
        
        null_handling_methods = [:ignore_nil!, :nil!, :null!]
        null_handling_methods.include?(method_name)
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