# frozen_string_literal: true

require "parser/current"
require "ostruct"
require_relative "operation_comment_parser"
require_relative "property_comment_parser"
require_relative "processors"
require_relative "ast_parser"

module RailsOpenapiGen::Parsers::Jbuilder
  class JbuilderParser
    attr_reader :jbuilder_path, :ast_parser

    # Initializes Jbuilder parser with template path
    # @param jbuilder_path [String] Path to Jbuilder template file
    def initialize(jbuilder_path)
      @jbuilder_path = jbuilder_path
      @properties = []
      @operation_info = nil
      @parsed_files = Set.new
      @operation_parser = nil
      @property_parser = nil
      @ast_parser = nil
    end

    # Main parsing method using AST-based architecture
    # @return [RailsOpenapiGen::AstNodes::BaseNode] Root AST node
    def parse
      @ast_parser = AstParser.new(jbuilder_path)

      return nil unless File.exist?(jbuilder_path)

      @ast_parser.parse
    end

    # Alias for backward compatibility
    alias parse_ast parse
  end
end
