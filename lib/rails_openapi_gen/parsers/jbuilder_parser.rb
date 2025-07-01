# frozen_string_literal: true

require "parser/current"
require "ostruct"

module RailsOpenapiGen
  module Parsers
    class JbuilderParser
      attr_reader :jbuilder_path

      def initialize(jbuilder_path)
        @jbuilder_path = jbuilder_path
        @properties = []
        @parsed_files = Set.new
      end

      def parse
        return @properties unless File.exist?(jbuilder_path)
        
        parse_file(jbuilder_path)
        @properties
      end

      private

      def parse_file(file_path)
        return if @parsed_files.include?(file_path)
        @parsed_files << file_path

        content = File.read(file_path)
        
        # Extract block comments first
        block_comments = extract_block_comments(content)
        
        ast, comments = Parser::CurrentRuby.parse_with_comments(content)
        
        # Combine line comments and block comments
        all_comments = comments + block_comments
        
        processor = JbuilderProcessor.new(file_path, all_comments)
        processor.process(ast)
        
        @properties.concat(processor.properties)
        
        processor.partials.each do |partial_path|
          parse_file(partial_path) if File.exist?(partial_path)
        end
      end

      def extract_block_comments(content)
        block_comments = []
        lines = content.lines
        
        i = 0
        while i < lines.length
          line = lines[i].strip
          if line.start_with?('=begin')
            # Found start of block comment
            comment_lines = []
            i += 1
            
            while i < lines.length && !lines[i].strip.start_with?('=end')
              comment_lines << lines[i]
              i += 1
            end
            
            # Create a mock comment object
            comment_text = comment_lines.join
            if comment_text.include?('@openapi')
              mock_comment = OpenStruct.new(
                text: comment_text,
                location: OpenStruct.new(line: i - comment_lines.length)
              )
              block_comments << mock_comment
            end
          end
          i += 1
        end
        
        block_comments
      end

      class JbuilderProcessor < Parser::AST::Processor
        attr_reader :properties, :partials

        def initialize(file_path, comments)
          @file_path = file_path
          @comments = comments
          @properties = []
          @partials = []
          @comment_parser = CommentParser.new
          @block_stack = []
          @current_object_properties = []
        end

        def on_send(node)
          receiver, method_name, *args = node.children
          
          if json_property?(receiver, method_name)
            process_json_property(node, method_name.to_s, args)
          elsif array_call?(receiver, method_name)
            process_array_property(node)
          elsif partial_call?(receiver, method_name)
            process_partial(args)
          end
          
          super
        end
        
        def on_block(node)
          send_node, _args, body = node.children
          receiver, method_name, *args = send_node.children
          
          if json_property?(receiver, method_name) && method_name != :array!
            # This is a nested object block like json.profile do
            process_block_property(node, method_name.to_s)
          elsif array_call?(receiver, method_name)
            # This is json.array! block
            @block_stack.push(:array)
            super
            @block_stack.pop
          else
            super
          end
        end

        private

        def json_property?(receiver, method_name)
          receiver && receiver.type == :send && receiver.children[1] == :json
        end

        def partial_call?(receiver, method_name)
          method_name == :partial! && (!receiver || receiver.type == :send && receiver.children[1] == :json)
        end

        def array_call?(receiver, method_name)
          method_name == :array! && receiver && receiver.type == :send && receiver.children[1] == :json
        end

        def process_json_property(node, property_name, args)
          comment_data = find_comment_for_node(node)
          
          # Check if we're inside an array block
          if @block_stack.last == :array
            process_simple_property(node, property_name, comment_data)
          else
            process_simple_property(node, property_name, comment_data)
          end
        end

        def process_array_property(node)
          comment_data = find_comment_for_node(node)
          
          # Mark this as an array root
          property_info = {
            property: "items", # Special property to indicate array items
            comment_data: comment_data || { type: "array", items: { type: "object" } },
            is_array_root: true
          }
          
          @properties << property_info
        end

        def process_block_property(node, property_name)
          comment_data = find_comment_for_node(node)
          
          property_info = {
            property: property_name,
            comment_data: comment_data || { type: "object" },
            is_object: true
          }
          
          @properties << property_info
        end

        def process_simple_property(node, property_name, comment_data)
          property_info = {
            property: property_name,
            comment_data: comment_data
          }
          
          unless comment_data && !comment_data.empty?
            property_info[:comment_data] = { type: "TODO: MISSING COMMENT" }
          end
          
          @properties << property_info
        end


        def process_partial(args)
          return if args.empty?
          
          partial_arg = args.first
          if partial_arg.type == :str
            partial_name = partial_arg.children.first
            partial_path = resolve_partial_path(partial_name)
            @partials << partial_path if partial_path
          end
        end

        def find_comment_for_node(node)
          line_number = node.location.line
          
          @comments.reverse.find do |comment|
            comment_line = comment.location.line
            comment_line == line_number - 1 || comment_line == line_number
          end&.then do |comment|
            @comment_parser.parse(comment.text)
          end
        end

        def resolve_partial_path(partial_name)
          dir = File.dirname(@file_path)
          
          if partial_name.include?("/")
            Rails.root.join("app", "views", "#{partial_name}.json.jbuilder")
          else
            File.join(dir, "_#{partial_name}.json.jbuilder")
          end
        end
      end
    end
  end
end