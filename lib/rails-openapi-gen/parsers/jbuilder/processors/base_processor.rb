# frozen_string_literal: true

require 'parser/current'
require_relative '../../../ast_nodes'

module RailsOpenapiGen
  module Parsers
    module Jbuilder
      module Processors
        class BaseProcessor < Parser::AST::Processor
          attr_reader :properties, :partials

          # Initializes base processor
          # @param file_path [String] Path to current file
          # @param property_parser [PropertyCommentParser] Parser for property comments
          def initialize(file_path, property_parser)
            super()  # Call parent initialize first, with no arguments
            @file_path = file_path
            @property_parser = property_parser
            @properties = []
            @partials = []
            @block_stack = []
            @current_object_properties = []
            @nested_objects = {}
            @conditional_stack = []
          end

          # Processes method call nodes - to be overridden by subclasses
          # @param node [Parser::AST::Node] Method call node
          # @return [void]
          def on_send(node)
            super(node)
          end

          # Processes block nodes - to be overridden by subclasses
          # @param node [Parser::AST::Node] Block node
          # @return [void]
          def on_block(node)
            super(node)
          end

          # Processes if statements to track conditional properties
          # @param node [Parser::AST::Node] If statement node
          # @return [void]
          def on_if(node)
            # Check if this if statement has a conditional comment
            comment_data = find_comment_for_node(node)

            if comment_data && comment_data[:conditional]
              @conditional_stack.push(true)
              super(node)
              @conditional_stack.pop
            else
              super(node)
            end
          end

          # Processes begin nodes (multiple statements)
          # @param node [Parser::AST::Node] Begin node
          # @return [void]
          def on_begin(node)
            # Just process all children normally
            super(node)
          end

          # Handler for missing node types
          # @param node [Parser::AST::Node] Node to process
          # @return [Parser::AST::Node, nil] The node or nil
          def handler_missing(node)
            node
          end

          protected

          # Finds OpenAPI comment for a given AST node
          # @param node [Parser::AST::Node] Node to find comment for
          # @return [Hash, nil] Parsed comment data or nil
          def find_comment_for_node(node)
            line_number = node.location.line
            @property_parser.find_property_comment_for_line(line_number)
          end

          # Resolves partial name to full file path
          # @param partial_name [String] Partial name (e.g., "users/user")
          # @return [String, nil] Full path to partial file or nil
          def resolve_partial_path(partial_name)
            dir = File.dirname(@file_path)

            if partial_name.include?('/')
              # Find the app/views directory from the current file path
              path_parts = @file_path.split('/')
              views_index = path_parts.rindex('views')
              if views_index
                views_path = path_parts[0..views_index].join('/')
                # For paths like 'users/user', convert to 'users/_user.json.jbuilder'
                parts = partial_name.split('/')
                dir_part = parts[0..-2].join('/')
                file_part = "_#{parts[-1]}"
                File.join(views_path, dir_part, "#{file_part}.json.jbuilder")
              else
                # For paths like 'users/user', convert to 'users/_user.json.jbuilder'
                parts = partial_name.split('/')
                dir_part = parts[0..-2].join('/')
                file_part = "_#{parts[-1]}"
                File.join(dir, dir_part, "#{file_part}.json.jbuilder")
              end
            else
              # Add underscore prefix if not already present
              filename = partial_name.start_with?('_') ? partial_name : "_#{partial_name}"
              File.join(dir, "#{filename}.json.jbuilder")
            end
          end

          # Parses a partial file to extract properties for nested objects
          # @param partial_path [String] Path to partial file
          # @return [Array<Hash>] Array of property definitions
          def parse_partial_for_nested_object(partial_path)
            # Create a new parser to parse the partial independently
            partial_parser = RailsOpenapiGen::Parsers::Jbuilder::JbuilderParser.new(partial_path)
            result = partial_parser.parse
            result[:properties]
          end

          # Adds a property to the properties array
          # @param property_node [PropertyNode, Hash] Property node or hash (for backward compatibility)
          # @return [void]
          def add_property(property_node)
            # Convert hash to PropertyNode if needed (backward compatibility)
            if property_node.is_a?(Hash)
              property_node = AstNodes::PropertyNodeFactory.from_hash(property_node)
            end

            # Mark as conditional if inside a conditional block
            if @conditional_stack.any?
              # Create a new node with conditional flag set
              property_node = create_conditional_node(property_node)
            end

            @properties << property_node
          end

          # Creates a conditional version of a property node
          # @param node [PropertyNode] Original property node
          # @return [PropertyNode] New conditional property node
          def create_conditional_node(node)
            case node
            when AstNodes::SimplePropertyNode
              AstNodes::PropertyNodeFactory.create_simple(
                property: node.property,
                comment_data: node.comment_data,
                is_conditional: true
              )
            when AstNodes::ArrayPropertyNode
              AstNodes::PropertyNodeFactory.create_array(
                property: node.property,
                comment_data: node.comment_data,
                is_conditional: true,
                array_item_properties: node.array_item_properties
              )
            when AstNodes::ObjectPropertyNode
              AstNodes::PropertyNodeFactory.create_object(
                property: node.property,
                comment_data: node.comment_data,
                is_conditional: true,
                nested_properties: node.nested_properties
              )
            when AstNodes::ArrayRootNode
              # Array root nodes cannot be conditional
              node
            else
              node
            end
          end

          # Pushes a block type to the stack
          # @param block_type [Symbol] Type of block (:array, :object, etc.)
          # @return [void]
          def push_block(block_type)
            @block_stack.push(block_type)
          end

          # Pops a block type from the stack
          # @return [Symbol, nil] Popped block type or nil
          def pop_block
            @block_stack.pop
          end

          # Checks if we're currently inside a specific block type
          # @param block_type [Symbol] Block type to check
          # @return [Boolean] True if inside the specified block type
          def inside_block?(block_type)
            @block_stack.last == block_type
          end

          # Processes a specific AST node
          # @param node [Parser::AST::Node] Node to process
          # @return [void]
          def process_node(node)
            return unless node
            
            case node.type
            when :send
              on_send(node)
            when :block
              on_block(node)
            when :if
              on_if(node)
            else
              # For other node types, recursively process children
              node.children.each { |child| process_node(child) if child.is_a?(Parser::AST::Node) }
            end
          end
        end
      end
    end
  end
end
