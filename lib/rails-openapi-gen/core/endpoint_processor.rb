# frozen_string_literal: true

require_relative 'schema_generation_result'

module RailsOpenapiGen::Core
  # Pure functional processor for converting endpoints to schemas
  # No side effects, no logging, returns Result types
  class EndpointProcessor
    attr_reader :jbuilder_parser_factory, :ast_to_schema_processor

    def initialize(jbuilder_parser_factory:, ast_to_schema_processor:)
      @jbuilder_parser_factory = jbuilder_parser_factory
      @ast_to_schema_processor = ast_to_schema_processor
    end

    # Process a single endpoint to generate schema
    # @param endpoint_info [Hash] Controller info with route
    # @return [SchemaGenerationResult] Success with schema data or Failure with error
    def call(endpoint_info)
      route = endpoint_info[:route]
      jbuilder_path = endpoint_info[:jbuilder_path]

      # Skip if no template
      unless jbuilder_path
        endpoint_name = "#{route[:method]} #{route[:path]}"
        return SchemaGenerationResult.failure(
          "No Jbuilder template found",
          warnings: ["Skipping #{endpoint_name}"]
        )
      end

      # Parse Jbuilder template
      parse_result = parse_jbuilder(jbuilder_path)
      return parse_result if parse_result.failure?

      ast_node = parse_result.value[:ast]
      components = parse_result.value[:components]

      # Convert AST to schema
      schema_result = convert_to_schema(ast_node)
      return schema_result if schema_result.failure?

      schema = schema_result.value

      # Validate schema quality
      warnings = validate_schema_quality(schema)

      # Build final result
      SchemaGenerationResult.success(
        {
          route: route,
          schema: schema,
          parameters: endpoint_info[:parameters] || {},
          components: components || {},
          operation: {} # Placeholder for operation metadata
        },
        warnings: warnings
      )
    rescue StandardError => e
      SchemaGenerationResult.failure(
        "Unexpected error: #{e.class} - #{e.message}",
        warnings: ["Stack trace: #{e.backtrace.first(3).join("\n")}"]
      )
    end

    private

    def parse_jbuilder(path)
      begin
        parser = @jbuilder_parser_factory.call(path)
        ast_node = parser.parse

        # Extract components if available
        components = if parser.respond_to?(:ast_parser) &&
                        parser.ast_parser &&
                        parser.ast_parser.respond_to?(:partial_components)
                      parser.ast_parser.partial_components
                    else
                      {}
                    end

        SchemaGenerationResult.success(ast: ast_node, components: components)
      rescue StandardError => e
        SchemaGenerationResult.failure("Failed to parse Jbuilder: #{e.message}")
      end
    end

    def convert_to_schema(ast_node)
      begin
        schema = @ast_to_schema_processor.process_to_schema(ast_node)
        SchemaGenerationResult.success(schema)
      rescue StandardError => e
        SchemaGenerationResult.failure("Failed to convert AST to schema: #{e.message}")
      end
    end

    def validate_schema_quality(schema)
      warnings = []

      if schema.nil? || schema.empty?
        warnings << "Generated empty schema"
      elsif schema["properties"] && schema["properties"].empty?
        warnings << "Schema has no properties"
      elsif schema["properties"] && schema["properties"].size < 2
        warnings << "Schema has very few properties (#{schema["properties"].size})"
      end

      # Check for TODO markers
      if schema.to_s.include?("TODO: MISSING COMMENT")
        missing_count = schema.to_s.scan(/TODO: MISSING COMMENT/).size
        warnings << "Schema contains #{missing_count} missing comment(s)"
      end

      warnings
    end
  end
end
