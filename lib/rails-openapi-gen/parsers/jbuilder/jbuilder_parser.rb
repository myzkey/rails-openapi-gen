# frozen_string_literal: true

require "parser/current"
require "ostruct"
require_relative "operation_comment_parser"
require_relative "property_comment_parser"
require_relative "processors"
require_relative "ast_parser"

module RailsOpenapiGen::Parsers::Jbuilder
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

    # New AST-based parsing method using the redesigned architecture
    # @return [RailsOpenapiGen::AstNodes::BaseNode] Root AST node
    def parse_ast
      return nil unless File.exist?(jbuilder_path)
      
      ast_parser = AstParser.new(jbuilder_path)
      ast_parser.parse
    end

    # Parse using new architecture and convert to legacy format for compatibility
    # @return [Hash] Hash with properties array and operation info (legacy format)
    def parse_with_new_architecture
      root_node = parse_ast
      return { properties: [], operation: nil } unless root_node
      
      # Convert AST nodes to legacy format
      properties = convert_ast_to_legacy_properties(root_node)
      
      # Extract operation info from comments (this would need to be implemented)
      operation_info = extract_operation_info_from_ast(root_node)
      
      { properties: properties, operation: operation_info }
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
      
      processor = Processors::CompositeProcessor.new(file_path, @property_parser)
      processor.process(ast)
      
      @properties.concat(processor.properties)
      
      processor.partials.each do |partial_path|
        parse_file(partial_path) if File.exist?(partial_path)
      end
    end

    # Convert AST nodes to legacy property format
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Root AST node
    # @return [Array<Hash>] Legacy properties array
    def convert_ast_to_legacy_properties(node)
      properties = []
      
      if node.respond_to?(:properties)
        node.properties.each do |property|
          properties << convert_node_to_legacy_hash(property)
        end
      elsif node.respond_to?(:items)
        # Handle array root node
        node.items.each do |item|
          properties << convert_node_to_legacy_hash(item)
        end
      end
      
      properties
    end

    # Convert a single AST node to legacy hash format
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] AST node
    # @return [Hash] Legacy property hash
    def convert_node_to_legacy_hash(node)
      case node
      when RailsOpenapiGen::AstNodes::PropertyNode
        {
          property: node.property_name,
          comment_data: node.comment_data&.to_h,
          is_conditional: node.is_conditional,
          node_type: :simple
        }
      when RailsOpenapiGen::AstNodes::ArrayNode
        {
          property: node.property_name,
          comment_data: node.comment_data&.to_h,
          is_conditional: node.is_conditional,
          is_array: true,
          is_array_root: node.root_array?,
          array_item_properties: convert_ast_to_legacy_properties(node),
          node_type: :array
        }
      when RailsOpenapiGen::AstNodes::ObjectNode
        {
          property: node.property_name,
          comment_data: node.comment_data&.to_h,
          is_conditional: node.is_conditional,
          is_object: true,
          nested_properties: convert_ast_to_legacy_properties(node),
          node_type: :object
        }
      when RailsOpenapiGen::AstNodes::PartialNode
        {
          property: node.property_name,
          comment_data: node.comment_data&.to_h,
          is_conditional: node.is_conditional,
          partial_path: node.partial_path,
          properties: convert_ast_to_legacy_properties(node),
          node_type: :partial
        }
      else
        {
          property: node.respond_to?(:property_name) ? node.property_name : 'unknown',
          comment_data: node.respond_to?(:comment_data) ? node.comment_data&.to_h : {},
          is_conditional: node.respond_to?(:is_conditional) ? node.is_conditional : false,
          node_type: :unknown
        }
      end
    end

    # Extract operation info from AST (placeholder implementation)
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Root AST node
    # @return [Hash, nil] Operation info
    def extract_operation_info_from_ast(node)
      # This would need to be implemented to extract operation-level comments
      # For now, fall back to existing operation parser
      @operation_info
    end
  end
end