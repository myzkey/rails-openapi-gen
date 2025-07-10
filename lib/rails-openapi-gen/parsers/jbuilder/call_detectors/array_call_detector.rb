# frozen_string_literal: true

module RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
  class ArrayCallDetector
    class << self
      def array_call?(receiver, method_name)
        method_name == :array! && receiver && receiver.type == :send && receiver.children[1] == :json
      end

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
