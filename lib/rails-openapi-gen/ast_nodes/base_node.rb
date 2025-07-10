# frozen_string_literal: true

module RailsOpenapiGen
  module AstNodes
  # Base class for all AST nodes in the Jbuilder parser
  # Provides common interface and basic functionality for tree structure
  class BaseNode
    attr_reader :parent, :children, :metadata

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
        children: @children.map(&:to_h)
      }
    end

    # Accept a visitor for visitor pattern implementation
    # @param visitor [Object] Visitor object
    # @return [Object] Result from visitor
    def accept(visitor)
      visitor.visit(self)
    end

    protected

    attr_writer :parent
  end
  end
end