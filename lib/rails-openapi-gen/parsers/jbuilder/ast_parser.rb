# frozen_string_literal: true

require "parser/current"
require_relative "../comment_parser"
require_relative "call_detectors"
require_relative "../../ast_nodes"

module RailsOpenapiGen::Parsers::Jbuilder
  # Main AST parser for Jbuilder templates
  # Orchestrates the parsing process using CallDetectors and building AstNodes
  class AstParser < Parser::AST::Processor
    attr_reader :file_path, :root_node, :current_context, :comment_parser

    def initialize(file_path)
      @file_path = file_path
      @root_node = RailsOpenapiGen::AstNodes::ObjectNode.new(property_name: 'root')
      @current_context = [@root_node]
      @comment_parser = RailsOpenapiGen::Parsers::CommentParser.new
      @conditional_stack = []
    end

    # Parse the Jbuilder template and return the root AST node
    # @param content [String, nil] Template content (will read from file if nil)
    # @return [RailsOpenapiGen::AstNodes::ObjectNode] Root AST node
    def parse(content = nil)
      content ||= File.read(@file_path)
      ast = Parser::CurrentRuby.parse(content)
      
      return @root_node unless ast
      
      # Store content for comment extraction
      @content_lines = content.lines.map(&:chomp)
      
      # Process the AST
      process(ast)
      
      @root_node
    end

    # Process send nodes (method calls)
    # @param node [Parser::AST::Node] Send node
    # @return [void]
    def on_send(node)
      receiver, method_name, *args = node.children
      
      # Find appropriate detector for this method call
      detector = CallDetectors::DetectorRegistry.find_detector(receiver, method_name, args)
      
      if detector
        process_detected_call(node, detector, receiver, method_name, args)
      else
        # Unknown method call, continue processing children
        super(node)
      end
    end

    # Process block nodes
    # @param node [Parser::AST::Node] Block node
    # @return [void]
    def on_block(node)
      send_node, args_node, body_node = node.children
      receiver, method_name, *args = send_node.children
      
      # Find appropriate detector for this method call
      detector = CallDetectors::DetectorRegistry.find_detector(receiver, method_name, args)
      
      if detector
        process_detected_block(node, detector, receiver, method_name, args, body_node)
      else
        # Unknown block, process body only
        process(body_node) if body_node
      end
    end

    # Process conditional nodes (if, unless, etc.)
    # @param node [Parser::AST::Node] Conditional node
    # @return [void] 
    def on_if(node)
      condition, true_branch, false_branch = node.children
      
      # Mark subsequent nodes as conditional
      @conditional_stack.push(true)
      
      # Process true branch
      process(true_branch) if true_branch
      
      # Process false branch (else/elsif)
      process(false_branch) if false_branch
      
      # Restore conditional state
      @conditional_stack.pop
    end

    alias on_unless on_if

    private

    # Process a detected method call
    # @param node [Parser::AST::Node] The full node
    # @param detector [Class] Detector class
    # @param receiver [Parser::AST::Node, nil] Method receiver
    # @param method_name [Symbol] Method name
    # @param args [Array<Parser::AST::Node>] Method arguments
    # @return [void]
    def process_detected_call(node, detector, receiver, method_name, args)
      case detector
      when CallDetectors::JsonCallDetector
        process_json_property_call(node, method_name, args)
      when CallDetectors::ArrayCallDetector
        process_array_call(node, method_name, args)
      when CallDetectors::PartialCallDetector
        process_partial_call(node, method_name, args)
      when CallDetectors::CacheCallDetector
        process_cache_call(node, method_name, args)
      else
        # For meta calls (key_format, null, etc.), just continue processing
        super(node)
      end
    end

    # Process a detected block
    # @param node [Parser::AST::Node] The full block node
    # @param detector [Class] Detector class
    # @param receiver [Parser::AST::Node, nil] Method receiver
    # @param method_name [Symbol] Method name
    # @param args [Array<Parser::AST::Node>] Method arguments
    # @param body [Parser::AST::Node, nil] Block body
    # @return [void]
    def process_detected_block(node, detector, receiver, method_name, args, body)
      case detector
      when CallDetectors::JsonCallDetector
        process_json_object_block(node, method_name, args, body)
      when CallDetectors::ArrayCallDetector
        process_array_block(node, method_name, args, body)
      when CallDetectors::CacheCallDetector
        process_cache_block(node, method_name, args, body)
      else
        # Unknown block type, process body
        process(body) if body
      end
    end

    # Process JSON property call (json.property_name value)
    # @param node [Parser::AST::Node] Method call node
    # @param method_name [Symbol] Property name
    # @param args [Array<Parser::AST::Node>] Arguments
    # @return [void]
    def process_json_property_call(node, method_name, args)
      comment_data = extract_comment_for_node(node)
      is_conditional = in_conditional_context?
      
      property_node = RailsOpenapiGen::AstNodes::NodeFactory.create_property(
        property_name: method_name.to_s,
        comment_data: comment_data,
        is_conditional: is_conditional
      )
      
      current_parent.add_property(property_node)
    end

    # Process JSON object block (json.property do...end)
    # @param node [Parser::AST::Node] Block node
    # @param method_name [Symbol] Property name
    # @param args [Array<Parser::AST::Node>] Arguments
    # @param body [Parser::AST::Node, nil] Block body
    # @return [void]
    def process_json_object_block(node, method_name, args, body)
      comment_data = extract_comment_for_node(node)
      is_conditional = in_conditional_context?
      
      object_node = RailsOpenapiGen::AstNodes::NodeFactory.create_object(
        property_name: method_name.to_s,
        comment_data: comment_data,
        is_conditional: is_conditional
      )
      
      # Add to current parent
      current_parent.add_property(object_node)
      
      # Process block body with object as context
      with_context(object_node) do
        process(body) if body
      end
    end

    # Process array call (json.array!)
    # @param node [Parser::AST::Node] Method call node
    # @param method_name [Symbol] Method name
    # @param args [Array<Parser::AST::Node>] Arguments
    # @return [void]
    def process_array_call(node, method_name, args)
      comment_data = extract_comment_for_node(node)
      is_conditional = in_conditional_context?
      
      # Check if this is a root array or property array
      is_root = current_parent == @root_node
      
      array_node = RailsOpenapiGen::AstNodes::NodeFactory.create_array(
        property_name: is_root ? nil : 'items',
        comment_data: comment_data,
        is_conditional: is_conditional,
        is_root_array: is_root
      )
      
      if is_root
        @root_node = array_node
      else
        current_parent.add_property(array_node)
      end
    end

    # Process array block (json.array! do...end)
    # @param node [Parser::AST::Node] Block node
    # @param method_name [Symbol] Method name
    # @param args [Array<Parser::AST::Node>] Arguments
    # @param body [Parser::AST::Node, nil] Block body
    # @return [void]
    def process_array_block(node, method_name, args, body)
      comment_data = extract_comment_for_node(node)
      is_conditional = in_conditional_context?
      
      # Check if this is a root array or property array
      is_root = current_parent == @root_node
      
      array_node = RailsOpenapiGen::AstNodes::NodeFactory.create_array(
        property_name: is_root ? nil : 'items',
        comment_data: comment_data,
        is_conditional: is_conditional,
        is_root_array: is_root
      )
      
      if is_root
        @root_node = array_node
      else
        current_parent.add_property(array_node)
      end
      
      # Process block body with array as context
      with_context(array_node) do
        process(body) if body
      end
    end

    # Process partial call (json.partial!)
    # @param node [Parser::AST::Node] Method call node
    # @param method_name [Symbol] Method name
    # @param args [Array<Parser::AST::Node>] Arguments
    # @return [void]
    def process_partial_call(node, method_name, args)
      comment_data = extract_comment_for_node(node)
      is_conditional = in_conditional_context?
      
      partial_path = CallDetectors::PartialCallDetector.extract_partial_path(args)
      local_vars = CallDetectors::PartialCallDetector.extract_locals(args)
      
      return unless partial_path
      
      partial_node = RailsOpenapiGen::AstNodes::NodeFactory.create_partial(
        partial_path: partial_path,
        comment_data: comment_data,
        is_conditional: is_conditional,
        local_variables: local_vars
      )
      
      # Parse the partial if it exists
      resolved_path = partial_node.resolve_path(@file_path)
      if File.exist?(resolved_path)
        partial_parser = self.class.new(resolved_path)
        partial_root = partial_parser.parse
        
        # Add parsed properties to the partial node
        if partial_root.respond_to?(:properties)
          partial_node.add_parsed_properties(partial_root.properties)
        end
      end
      
      current_parent.add_property(partial_node)
    end

    # Process cache call (json.cache!)
    # @param node [Parser::AST::Node] Method call node
    # @param method_name [Symbol] Method name
    # @param args [Array<Parser::AST::Node>] Arguments
    # @return [void]
    def process_cache_call(node, method_name, args)
      # Cache calls don't affect schema structure, just continue processing
      super(node)
    end

    # Process cache block (json.cache! do...end)
    # @param node [Parser::AST::Node] Block node
    # @param method_name [Symbol] Method name
    # @param args [Array<Parser::AST::Node>] Arguments
    # @param body [Parser::AST::Node, nil] Block body
    # @return [void]
    def process_cache_block(node, method_name, args, body)
      # Cache blocks don't affect schema structure, just process the body
      process(body) if body
    end

    # Extract comment data for a node
    # @param node [Parser::AST::Node] Node to extract comment for
    # @return [RailsOpenapiGen::AstNodes::CommentData, nil] Comment data
    def extract_comment_for_node(node)
      return nil unless node.location
      
      line_number = node.location.line
      
      # Look for comments in the lines before this node
      (line_number - 1).downto([line_number - 3, 0].max) do |line_index|
        line = @content_lines[line_index]
        next unless line && line.include?('@openapi')
        
        parsed_comment = @comment_parser.parse(line)
        next unless parsed_comment
        
        return RailsOpenapiGen::AstNodes::CommentData.new(
          type: parsed_comment[:type],
          description: parsed_comment[:description],
          required: parsed_comment[:required],
          enum: parsed_comment[:enum],
          conditional: parsed_comment[:conditional]
        )
      end
      
      nil
    end

    # Check if currently in a conditional context
    # @return [Boolean] True if in conditional context
    def in_conditional_context?
      !@conditional_stack.empty?
    end

    # Get the current parent node
    # @return [RailsOpenapiGen::AstNodes::BaseNode] Current parent node
    def current_parent
      @current_context.last
    end

    # Execute block with a new context
    # @param new_context [RailsOpenapiGen::AstNodes::BaseNode] New context node
    # @yield Block to execute in new context
    # @return [void]
    def with_context(new_context)
      @current_context.push(new_context)
      yield
    ensure
      @current_context.pop
    end
  end
end