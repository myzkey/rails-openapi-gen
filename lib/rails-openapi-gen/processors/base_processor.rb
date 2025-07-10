# frozen_string_literal: true

module RailsOpenapiGen::Processors
  # Base class for all processors that convert AST nodes to output formats
  # Implements visitor pattern for processing different node types
  class BaseProcessor
    # Process an AST node and return converted output
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] AST node to process
    # @return [Object] Processed output
    def process(node)
      return nil unless node
      
      if node.respond_to?(:accept)
        node.accept(self)
      else
        visit(node)
      end
    end

    # Generic visit method for nodes that don't implement accept
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Node to visit
    # @return [Object] Processed output
    def visit(node)
      case node
      when RailsOpenapiGen::AstNodes::PropertyNode
        visit_property(node)
      when RailsOpenapiGen::AstNodes::ArrayNode
        visit_array(node)
      when RailsOpenapiGen::AstNodes::ObjectNode
        visit_object(node)
      when RailsOpenapiGen::AstNodes::PartialNode
        visit_partial(node)
      else
        visit_unknown(node)
      end
    end

    # Visit a property node
    # @param node [RailsOpenapiGen::AstNodes::PropertyNode] Property node
    # @return [Object] Processed output
    def visit_property(node)
      raise NotImplementedError, "#{self.class} must implement #visit_property"
    end

    # Visit an array node
    # @param node [RailsOpenapiGen::AstNodes::ArrayNode] Array node
    # @return [Object] Processed output
    def visit_array(node)
      raise NotImplementedError, "#{self.class} must implement #visit_array"
    end

    # Visit an object node
    # @param node [RailsOpenapiGen::AstNodes::ObjectNode] Object node
    # @return [Object] Processed output
    def visit_object(node)
      raise NotImplementedError, "#{self.class} must implement #visit_object"
    end

    # Visit a partial node
    # @param node [RailsOpenapiGen::AstNodes::PartialNode] Partial node
    # @return [Object] Processed output
    def visit_partial(node)
      raise NotImplementedError, "#{self.class} must implement #visit_partial"
    end

    # Visit an unknown node type
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Unknown node
    # @return [Object] Processed output
    def visit_unknown(node)
      # Default implementation returns nil for unknown nodes
      nil
    end

    # Process multiple nodes
    # @param nodes [Array<RailsOpenapiGen::AstNodes::BaseNode>] Nodes to process
    # @return [Array<Object>] Array of processed outputs
    def process_nodes(nodes)
      return [] unless nodes.respond_to?(:map)
      
      nodes.map { |node| process(node) }.compact
    end

    # Check if node should be processed based on conditions
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Node to check
    # @return [Boolean] True if node should be processed
    def should_process?(node)
      return false unless node
      
      # Can be overridden in subclasses for custom filtering
      true
    end

    protected

    # Extract description from comment data
    # @param comment_data [RailsOpenapiGen::AstNodes::CommentData, nil] Comment data
    # @return [String, nil] Description
    def extract_description(comment_data)
      comment_data&.description
    end

    # Extract OpenAPI type from comment data
    # @param comment_data [RailsOpenapiGen::AstNodes::CommentData, nil] Comment data
    # @param default_type [String] Default type if not specified
    # @return [String] OpenAPI type
    def extract_type(comment_data, default_type = 'string')
      comment_data&.openapi_type || default_type
    end

    # Check if property is required
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Node to check
    # @return [Boolean] True if property is required
    def required?(node)
      node.respond_to?(:required?) ? node.required? : false
    end

    # Check if property is conditional
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Node to check
    # @return [Boolean] True if property is conditional
    def conditional?(node)
      node.respond_to?(:is_conditional) ? node.is_conditional : false
    end
  end
end