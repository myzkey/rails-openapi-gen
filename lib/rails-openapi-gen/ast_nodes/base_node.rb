# frozen_string_literal: true

module RailsOpenapiGen
  module AstNodes
    # Base class for all AST nodes in the Jbuilder parser
    # Provides common interface and basic functionality for tree structure
    class BaseNode
      attr_accessor :parent
      attr_reader :children, :metadata

      def initialize(parent: nil, metadata: {})
        @parent = parent
        @children = []
        @metadata = metadata
      end

      # Add a child node to this node
      # @param child [BaseNode] Child node to add
      # @return [BaseNode] The added child node
      def add_child(child)
        child.parent = self if child.respond_to?(:parent=)
        @children << child
        child
      end

      # Remove a child node from this node
      # @param child [BaseNode] Child node to remove
      # @return [BaseNode, nil] The removed child node or nil
      def remove_child(child)
        @children.delete(child)
      end

      # Get all descendants (children and their children recursively)
      # @return [Array<BaseNode>] All descendant nodes
      def descendants
        result = []
        @children.each do |child|
          result << child
          result.concat(child.descendants) if child.respond_to?(:descendants)
        end
        result
      end

      # Check if this node is a leaf (has no children)
      # @return [Boolean] True if this node has no children
      def leaf?
        @children.empty?
      end

      # Check if this node is the root (has no parent)
      # @return [Boolean] True if this node has no parent
      def root?
        @parent.nil?
      end

      # Get the root node of the tree
      # @return [BaseNode] The root node
      def root
        return self if root?

        @parent.root
      end

      # Convert node to hash representation
      # @return [Hash] Hash representation of the node
      def to_h
        {
          node_type: self.class.name.split('::').last.downcase.gsub('node', ''),
          metadata: @metadata,
          children: @children.map { |child| child.respond_to?(:to_h) ? child.to_h : child }
        }
      end

      # Accept a visitor for visitor pattern implementation
      # @param visitor [Object] Visitor object
      # @return [Object] Result from visitor
      def accept(visitor)
        visitor.visit(self)
      end

      # Pretty print the AST tree structure for debugging
      # @param indent [Integer] Current indentation level
      # @return [void]
      def pretty_print(indent = 0)
        pad = '  ' * indent
        node_name = self.class.name.split('::').last
        summary = summary_attributes

        puts "#{pad}#{tree_symbol(indent)} #{node_name}#{summary.empty? ? '' : " (#{summary})"}"

        @children.each_with_index do |child, _index|
          child.pretty_print(indent + 1) if child.respond_to?(:pretty_print)
        end
      end

      # Print just this node without children
      # @return [String] Single line representation
      def debug_line
        node_name = self.class.name.split('::').last
        summary = summary_attributes
        "#{node_name}#{summary.empty? ? '' : " (#{summary})"}"
      end

      # Generate summary attributes for debugging display
      # @return [String] Summary of key attributes
      def summary_attributes
        attrs = []

        # Common attributes that most nodes might have
        attrs << "name=#{property_name}" if respond_to?(:property_name) && property_name

        if respond_to?(:comment_data) && comment_data
          attrs << "type=#{comment_data.type}" if comment_data.type
          attrs << "required=#{comment_data.required?}" if comment_data.respond_to?(:required?)
          attrs << "desc=#{comment_data.description[0..30]}..." if comment_data.description && comment_data.description.length > 30
          attrs << "desc=#{comment_data.description}" if comment_data.description && comment_data.description.length <= 30
        end

        attrs << "children=#{@children.size}" if @children.size > 0
        attrs << "conditional" if respond_to?(:is_conditional) && is_conditional

        attrs.join(', ')
      end

      private

      # Generate tree symbol for pretty printing
      # @param indent [Integer] Current indentation level
      # @return [String] Tree symbol (├── or └──)
      def tree_symbol(indent)
        return '└─' if indent == 0

        '├─'
      end

      # No longer need protected attr_writer since we have attr_accessor above
    end
  end
end
