# frozen_string_literal: true

module RailsOpenapiGen::Parsers::Jbuilder::Processors
  autoload :BaseProcessor, "rails-openapi-gen/parsers/jbuilder/processors/base_processor"
  autoload :CompositeProcessor, "rails-openapi-gen/parsers/jbuilder/processors/composite_processor"
  autoload :ArrayProcessor, "rails-openapi-gen/parsers/jbuilder/processors/array_processor"
  autoload :ObjectProcessor, "rails-openapi-gen/parsers/jbuilder/processors/object_processor"
  autoload :PropertyProcessor, "rails-openapi-gen/parsers/jbuilder/processors/property_processor"
  autoload :PartialProcessor, "rails-openapi-gen/parsers/jbuilder/processors/partial_processor"
end