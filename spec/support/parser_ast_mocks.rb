# frozen_string_literal: true

# Shared mock definitions for Parser::AST classes used in tests
# This prevents conflicts between test files that define the same mocks

module Parser
  module AST
    class Processor
      def initialize; end
      def process(node); end
      def process_children(node); end
    end
    
    class Node
      attr_reader :type, :children, :location
      
      def initialize(type, children = [], location = nil)
        @type = type
        @children = children
        @location = location || double('location', line: 1)
      end
      
      # Add updated method for Parser 3.1.3 compatibility
      def updated(new_type = nil, new_children = nil, new_properties = {})
        self.class.new(new_type || @type, new_children || @children, @location)
      end
    end
  end
end