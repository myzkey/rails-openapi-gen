# frozen_string_literal: true

require "parser/current"
require "ostruct"
require_relative "operation_comment_parser"
require_relative "property_comment_parser"
require_relative "processors/composite_processor"

module RailsOpenapiGen
  module Parsers
    module Jbuilder
      class JbuilderParser
      attr_reader :jbuilder_path

      # Initializes Jbuilder parser with template path
      # @param jbuilder_path [String] Path to Jbuilder template file
      def initialize(jbuilder_path)
        @jbuilder_path = jbuilder_path
        @properties = []
        @operation_info = nil
        @parsed_files = Set.new
        @operation_parser = nil
        @property_parser = nil
      end

      # Parses Jbuilder template to extract properties and operation info
      # @return [Hash] Hash with properties array and operation info
      def parse
        return { properties: @properties, operation: @operation_info } unless File.exist?(jbuilder_path)
        
        parse_file(jbuilder_path)
        { properties: @properties, operation: @operation_info }
      end

      private

      # Recursively parses a Jbuilder file and its partials
      # @param file_path [String] Path to file to parse
      # @return [void]
      def parse_file(file_path)
        return if @parsed_files.include?(file_path)
        @parsed_files << file_path

        content = File.read(file_path)
        
        ast, comments = Parser::CurrentRuby.parse_with_comments(content)
        
        # Initialize parsers with comments
        @operation_parser ||= OperationCommentParser.new(comments)
        @property_parser ||= PropertyCommentParser.new(comments)
        
        # Parse operation info once
        @operation_info ||= @operation_parser.parse_operation_info
        
        processor = Jbuilder::Processors::CompositeProcessor.new(file_path, @property_parser)
        processor.process(ast)
        
        @properties.concat(processor.properties)
        
        processor.partials.each do |partial_path|
          parse_file(partial_path) if File.exist?(partial_path)
        end
      end

      end
    end
  end
end