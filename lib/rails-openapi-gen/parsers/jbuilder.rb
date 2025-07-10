# frozen_string_literal: true

module RailsOpenapiGen::Parsers::Jbuilder
  autoload :JbuilderParser, "rails-openapi-gen/parsers/jbuilder/jbuilder_parser"
  autoload :AstParser, "rails-openapi-gen/parsers/jbuilder/ast_parser"
  autoload :CallDetectors, "rails-openapi-gen/parsers/jbuilder/call_detectors"
  autoload :Processors, "rails-openapi-gen/parsers/jbuilder/processors"
  autoload :OperationCommentParser, "rails-openapi-gen/parsers/jbuilder/operation_comment_parser"
  autoload :PropertyCommentParser, "rails-openapi-gen/parsers/jbuilder/property_comment_parser"
end