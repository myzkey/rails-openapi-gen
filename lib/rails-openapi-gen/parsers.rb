# frozen_string_literal: true

module RailsOpenapiGen::Parsers
  autoload :CommentParser, "rails-openapi-gen/parsers/comment_parser"
  autoload :ControllerParser, "rails-openapi-gen/parsers/controller_parser"
  autoload :RoutesParser, "rails-openapi-gen/parsers/routes_parser"
  autoload :Jbuilder, "rails-openapi-gen/parsers/jbuilder"
  autoload :TemplateProcessors, "rails-openapi-gen/parsers/template_processors"
end