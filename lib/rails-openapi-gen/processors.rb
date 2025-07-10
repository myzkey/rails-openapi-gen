# frozen_string_literal: true

module RailsOpenapiGen::Processors
  autoload :BaseProcessor, "rails-openapi-gen/processors/base_processor"
  autoload :OpenApiSchemaProcessor, "rails-openapi-gen/processors/openapi_schema_processor"
  autoload :AstToSchemaProcessor, "rails-openapi-gen/processors/ast_to_schema_processor"
end