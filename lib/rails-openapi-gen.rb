# frozen_string_literal: true

require 'rails-openapi-gen/version'
require 'rails-openapi-gen/helpers/logger'
require 'rails-openapi-gen/configuration'
require 'parser/current'
require 'pp'

# Zeitwerk autoloading setup
module RailsOpenapiGen
  autoload :AstNodes, "rails-openapi-gen/ast_nodes"
  autoload :Parsers, "rails-openapi-gen/parsers"
  autoload :Processors, "rails-openapi-gen/processors"
  autoload :Generators, "rails-openapi-gen/generators"
  autoload :Commands, "rails-openapi-gen/commands"
  autoload :Core, "rails-openapi-gen/core"
end

# Direct requires for core components that don't follow autoload patterns
require 'rails-openapi-gen/generators/yaml_generator'

# Rails integration is handled by Engine
if defined?(Rails::Engine)
  require 'rails-openapi-gen/engine'
end

module RailsOpenapiGen
  class Error < StandardError; end
  class ParseError < Error; end

  class << self
    # Returns the logger instance
    # @return [RailsOpenapiGen::Logger]
    def logger
      @logger ||= Logger.instance
    end
    # Generates OpenAPI specification from Rails application
    # @return [void]
    def generate
      Commands::Generator.new.run
    end

    # Validates OpenAPI comments and uncommitted changes
    # @return [void]
    def check
      Commands::Validator.new.run
    end

    # Imports OpenAPI specification and generates @openapi comments in Jbuilder files
    # @param openapi_file [String, nil] Path to OpenAPI specification file (defaults to openapi/openapi.yaml)
    # @return [void]
    def import(openapi_file = nil)
      Commands::Importer.new(openapi_file).run
    end
  end

end
