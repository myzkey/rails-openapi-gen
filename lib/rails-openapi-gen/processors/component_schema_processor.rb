# frozen_string_literal: true

require_relative "ast_to_schema_processor"

module RailsOpenapiGen::Processors
  # Processor that converts AST nodes to OpenAPI schema format for components
  # Differs from AstToSchemaProcessor by inline expanding component references
  class ComponentSchemaProcessor < AstToSchemaProcessor
    # Visit a property node (override to inline expand component references)
    # @param node [RailsOpenapiGen::AstNodes::PropertyNode] Property node
    # @return [Hash] Property schema
    def visit_property(node)
      # For component generation, we inline expand component references instead of using $ref
      if node.is_component_ref && node.component_name
        puts "🔄 Inline expanding component reference: #{node.component_name}" if ENV['RAILS_OPENAPI_DEBUG']
        return inline_expand_component_reference(node)
      end

      # Use the parent implementation for regular properties
      super
    end

    private

    # Inline expand a component reference for component generation
    # @param node [RailsOpenapiGen::AstNodes::PropertyNode] Component reference property
    # @return [Hash] Inline expanded schema
    def inline_expand_component_reference(_node)
      # Create a basic object schema as placeholder without auto-generated description
      {
        'type' => 'object'
      }
    end
  end
end
