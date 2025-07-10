# frozen_string_literal: true

require "parser/current"
require "ostruct"

module RailsOpenapiGen
  module Parsers
    class JbuilderParser
      attr_reader :jbuilder_path

      # Initializes Jbuilder parser with template path
      # @param jbuilder_path [String] Path to Jbuilder template file
      def initialize(jbuilder_path)
        @jbuilder_path = jbuilder_path
        @properties = []
        @operation_info = nil
        @parsed_files = Set.new
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
        
        # Extract block comments first
        block_comments = extract_block_comments(content)
        
        ast, comments = Parser::CurrentRuby.parse_with_comments(content)
        
        # Combine line comments and block comments
        all_comments = comments + block_comments
        
        processor = JbuilderProcessor.new(file_path, all_comments)
        processor.process(ast)
        
        @properties.concat(processor.properties)
        @operation_info ||= processor.operation_info
        
        processor.partials.each do |partial_path|
          parse_file(partial_path) if File.exist?(partial_path)
        end
      end

      # Extracts block comments (=begin/=end) from file content
      # @param content [String] File content
      # @return [Array<OpenStruct>] Array of mock comment objects
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
        attr_reader :properties, :partials, :operation_info

        # Initializes AST processor for Jbuilder parsing
        # @param file_path [String] Path to current file
        # @param comments [Array] Array of comment objects
        def initialize(file_path, comments)
          @file_path = file_path
          @comments = comments
          @operation_info = nil
          @properties = []
          @partials = []
          @comment_parser = CommentParser.new
          @block_stack = []
          @current_object_properties = []
          @nested_objects = {}
          @conditional_stack = []
        end

        # Processes method call nodes to extract JSON properties
        # @param node [Parser::AST::Node] Method call node
        # @return [void]
        def on_send(node)
          receiver, method_name, *args = node.children
          
          if cache_call?(receiver, method_name) || cache_if_call?(receiver, method_name) || jbuilder_helper?(receiver, method_name)
            # Skip Jbuilder helper methods - they are not JSON properties
            super
          elsif array_call?(receiver, method_name)
            # Check if this is an array with partial
            if args.any? && args.any? { |arg| arg.type == :hash && has_partial_key?(arg) }
              process_array_with_partial(node, args)
            else
              process_array_property(node)
            end
          elsif partial_call?(receiver, method_name)
            process_partial(args)
          elsif json_property?(receiver, method_name)
            process_json_property(node, method_name.to_s, args)
          end
          
          super
        end
        
        # Processes block nodes for nested objects and array iterations
        # @param node [Parser::AST::Node] Block node
        # @return [void]
        def on_block(node)
          send_node, args_node, body = node.children
          receiver, method_name, *send_args = send_node.children
          
          if cache_call?(receiver, method_name) || cache_if_call?(receiver, method_name)
            # This is json.cache! or json.cache_if! block - just process the block contents
            process(body) if body
          elsif json_property?(receiver, method_name) && method_name != :array!
            # Check if this is an array iteration block (has block arguments)
            if args_node && args_node.type == :args && args_node.children.any?
              # This is an array iteration block like json.tags @tags do |tag|
              process_array_iteration_block(node, method_name.to_s)
            else
              # This is a nested object block like json.profile do
              process_nested_object_block(node, method_name.to_s)
            end
          elsif array_call?(receiver, method_name)
            # This is json.array! block
            @block_stack.push(:array)
            super
            @block_stack.pop
          else
            super
          end
        end

        # Processes if statements to track conditional properties
        # @param node [Parser::AST::Node] If statement node
        # @return [void]
        def on_if(node)
          # Check if this if statement has a conditional comment
          comment_data = find_comment_for_node(node)
          
          if comment_data && comment_data[:conditional]
            @conditional_stack.push(true)
            super
            @conditional_stack.pop
          else
            super
          end
        end

        private

        # Checks if node represents a json property call
        # @param receiver [Parser::AST::Node] Receiver node
        # @param method_name [Symbol] Method name
        # @return [Boolean] True if json property call
        def json_property?(receiver, method_name)
          receiver && receiver.type == :send && receiver.children[1] == :json
        end

        # Checks if node represents a partial render call
        # @param receiver [Parser::AST::Node] Receiver node
        # @param method_name [Symbol] Method name
        # @return [Boolean] True if partial call
        def partial_call?(receiver, method_name)
          method_name == :partial! && (!receiver || receiver.type == :send && receiver.children[1] == :json)
        end

        # Checks if node represents a json.array! call
        # @param receiver [Parser::AST::Node] Receiver node
        # @param method_name [Symbol] Method name
        # @return [Boolean] True if array call
        def array_call?(receiver, method_name)
          method_name == :array! && receiver && receiver.type == :send && receiver.children[1] == :json
        end

        # Checks if node represents a json.cache! call
        # @param receiver [Parser::AST::Node] Receiver node
        # @param method_name [Symbol] Method name
        # @return [Boolean] True if cache call
        def cache_call?(receiver, method_name)
          method_name == :cache! && receiver && receiver.type == :send && receiver.children[1] == :json
        end

        # Checks if node represents a json.cache_if! call
        # @param receiver [Parser::AST::Node] Receiver node
        # @param method_name [Symbol] Method name
        # @return [Boolean] True if cache_if call
        def cache_if_call?(receiver, method_name)
          method_name == :cache_if! && receiver && receiver.type == :send && receiver.children[1] == :json
        end

        # Checks if node represents a Jbuilder helper method that should be ignored
        # @param receiver [Parser::AST::Node] Receiver node
        # @param method_name [Symbol] Method name
        # @return [Boolean] True if helper method
        def jbuilder_helper?(receiver, method_name)
          helper_methods = [:key_format!, :ignore_nil!, :merge!, :deep_format_keys!, :set!, :child!, :nil!, :null!, :cache_root!]
          helper_methods.include?(method_name) && receiver && receiver.type == :send && receiver.children[1] == :json
        end

        # Processes a simple JSON property assignment
        # @param node [Parser::AST::Node] Property node
        # @param property_name [String] Name of the property
        # @param args [Array] Method arguments
        # @return [void]
        def process_json_property(node, property_name, args)
          comment_data = find_comment_for_node(node)
          
          # Check if we're inside an array block
          if @block_stack.last == :array
            process_simple_property(node, property_name, comment_data)
          else
            process_simple_property(node, property_name, comment_data)
          end
        end

        # Processes json.array! calls to create array schema
        # @param node [Parser::AST::Node] Array call node
        # @return [void]
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
        
        # Processes json.array! with partial rendering
        # @param node [Parser::AST::Node] Array call node
        # @param args [Array] Array call arguments
        # @return [void]
        def process_array_with_partial(node, args)
          # Extract partial path from the hash arguments
          partial_path = nil
          args.each do |arg|
            if arg.type == :hash
              arg.children.each do |pair|
                if pair.type == :pair
                  key, value = pair.children
                  if key.type == :sym && key.children.first == :partial && value.type == :str
                    partial_path = value.children.first
                    break
                  end
                end
              end
            end
          end
          
          if partial_path
            # Resolve the partial path and parse it
            resolved_path = resolve_partial_path(partial_path)
            if resolved_path && File.exist?(resolved_path)
              # Parse the partial to get its properties
              partial_parser = JbuilderParser.new(resolved_path)
              partial_result = partial_parser.parse
              
              # Create array schema with items from the partial
              property_info = {
                property: "items",
                comment_data: { type: "array" },
                is_array_root: true,
                array_item_properties: partial_result[:properties]
              }
              
              @properties << property_info
            else
              # Fallback to regular array processing
              process_array_property(node)
            end
          else
            # Fallback to regular array processing
            process_array_property(node)
          end
        end
        
        # Checks if hash node contains a :partial key
        # @param hash_node [Parser::AST::Node] Hash node to check
        # @return [Boolean] True if partial key exists
        def has_partial_key?(hash_node)
          hash_node.children.any? do |pair|
            if pair.type == :pair
              key, _value = pair.children
              key.type == :sym && key.children.first == :partial
            end
          end
        end

        # Processes array iteration blocks (e.g., json.tags @tags do |tag|)
        # @param node [Parser::AST::Node] Block node
        # @param property_name [String] Array property name
        # @return [void]
        def process_array_iteration_block(node, property_name)
          comment_data = find_comment_for_node(node)
          
          # Save current context
          previous_properties = @properties.dup
          previous_partials = @partials.dup
          
          # Create a temporary properties array for array items
          @properties = []
          @partials = []
          @block_stack.push(:array)
          
          # Process the block contents
          send_node, _args, body = node.children
          process(body) if body
          
          # Collect item properties
          item_properties = @properties.dup
          
          # Process any partials found in this block
          @partials.each do |partial_path|
            if File.exist?(partial_path)
              partial_properties = parse_partial_for_nested_object(partial_path)
              item_properties.concat(partial_properties)
            end
          end
          
          # Restore context
          @properties = previous_properties
          @partials = previous_partials
          @block_stack.pop
          
          # Build array schema with items
          property_info = {
            property: property_name,
            comment_data: comment_data || { type: "array" },
            is_array: true,
            array_item_properties: item_properties
          }
          
          @properties << property_info
        end
        
        # Processes nested object blocks (e.g., json.profile do)
        # @param node [Parser::AST::Node] Block node
        # @param property_name [String] Object property name
        # @return [void]
        def process_nested_object_block(node, property_name)
          comment_data = find_comment_for_node(node)
          
          # Save current context
          previous_nested_objects = @nested_objects.dup
          previous_properties = @properties.dup
          previous_partials = @partials.dup
          
          # Create a temporary properties array for this nested object
          @properties = []
          @partials = []
          @block_stack.push(:object)
          
          # Process the block contents
          send_node, _args, body = node.children
          process(body) if body
          
          # Collect nested properties
          nested_properties = @properties.dup
          
          # Process any partials found in this block
          @partials.each do |partial_path|
            if File.exist?(partial_path)
              partial_properties = parse_partial_for_nested_object(partial_path)
              nested_properties.concat(partial_properties)
            end
          end
          
          # Restore context
          @properties = previous_properties
          @partials = previous_partials # Don't add nested partials to main partials
          @nested_objects = previous_nested_objects
          @block_stack.pop
          
          # Store nested object info
          @nested_objects[property_name] = nested_properties
          
          # Add the parent property
          property_info = {
            property: property_name,
            comment_data: comment_data || { type: "object" },
            is_object: true,
            nested_properties: nested_properties
          }
          
          # Mark as optional if inside a conditional block
          if @conditional_stack.any?
            property_info[:is_conditional] = true
          end
          
          @properties << property_info
        end

        # Processes a simple property assignment
        # @param node [Parser::AST::Node] Property node
        # @param property_name [String] Name of the property
        # @param comment_data [Hash, nil] Parsed comment data
        # @return [void]
        def process_simple_property(node, property_name, comment_data)
          property_info = {
            property: property_name,
            comment_data: comment_data
          }
          
          unless comment_data && !comment_data.empty?
            property_info[:comment_data] = { type: "TODO: MISSING COMMENT" }
          end
          
          # Mark as optional if inside a conditional block
          if @conditional_stack.any?
            property_info[:is_conditional] = true
          end
          
          @properties << property_info
        end


        # Processes partial render calls to track dependencies
        # @param args [Array] Partial call arguments
        # @return [void]
        def process_partial(args)
          return if args.empty?
          
          partial_arg = args.first
          if partial_arg.type == :str
            partial_name = partial_arg.children.first
            partial_path = resolve_partial_path(partial_name)
            @partials << partial_path if partial_path
          end
        end

        # Finds OpenAPI comment for a given AST node
        # @param node [Parser::AST::Node] Node to find comment for
        # @return [Hash, nil] Parsed comment data or nil
        def find_comment_for_node(node)
          line_number = node.location.line
          
          # First check all comments for operation info
          @comments.each do |comment|
            parsed = @comment_parser.parse(comment.text)
            if parsed&.dig(:operation) && @operation_info.nil?
              @operation_info = parsed[:operation]
            end
          end
          
          # Then find comment for the specific node
          @comments.reverse.find do |comment|
            comment_line = comment.location.line
            comment_line == line_number - 1 || comment_line == line_number
          end&.then do |comment|
            @comment_parser.parse(comment.text)
          end
        end

        # Resolves partial name to full file path
        # @param partial_name [String] Partial name (e.g., "users/user")
        # @return [String, nil] Full path to partial file or nil
        def resolve_partial_path(partial_name)
          dir = File.dirname(@file_path)
          
          if partial_name.include?("/")
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
              File.join(dir, "#{partial_name}.json.jbuilder")
            end
          else
            File.join(dir, "_#{partial_name}.json.jbuilder")
          end
        end
        
        # Parses a partial file to extract properties for nested objects
        # @param partial_path [String] Path to partial file
        # @return [Array<Hash>] Array of property definitions
        def parse_partial_for_nested_object(partial_path)
          # Create a new parser to parse the partial independently
          partial_parser = JbuilderParser.new(partial_path)
          result = partial_parser.parse
          result[:properties]
        end
      end
    end
  end
end