# frozen_string_literal: true

module RailsOpenapiGen
  module Parsers
    module Jbuilder
      module CallDetectors
        class ObjectManipulationDetector
          class << self
            # Detects if node represents an object manipulation method
            # @param receiver [Parser::AST::Node] Receiver node
            # @param method_name [Symbol] Method name
            # @return [Boolean] True if object manipulation method
            def object_manipulation?(receiver, method_name)
              return false unless json_receiver?(receiver)
              
              object_manipulation_methods = [:merge!, :set!, :child!, :cache_root!]
              object_manipulation_methods.include?(method_name)
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