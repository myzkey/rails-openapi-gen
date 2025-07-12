# frozen_string_literal: true

require "parser/current"
require "set"
require_relative "../comment_parser"
require_relative "call_detectors"
require_relative "../../ast_nodes"

module RailsOpenapiGen::Parsers::Jbuilder
  # Main AST parser for Jbuilder templates
  # Orchestrates the parsing process using CallDetectors and building AstNodes
  class AstParser < Parser::AST::Processor
    attr_reader :file_path, :root_node, :current_context, :comment_parser, :partial_components

    def initialize(file_path, parser_version: Parser::CurrentRuby)
      @file_path = file_path
      @parser_version = parser_version
      @root_node = RailsOpenapiGen::AstNodes::ObjectNode.new(property_name: 'root')
      @current_context = [@root_node]
      @comment_parser = RailsOpenapiGen::Parsers::CommentParser.new
      @conditional_stack = []
      @partial_components = {}
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
      
      puts "🔍 DEBUG: Processing send node: #{method_name}, receiver: #{receiver}" if ENV['RAILS_OPENAPI_DEBUG']
      
      # Debug partial calls
      if ENV['RAILS_OPENAPI_DEBUG'] && method_name == :partial!
        puts "🔍 Found partial! call: #{method_name}"
        puts "   receiver: #{receiver&.inspect}"
        puts "   args: #{args.inspect}"
      end
      
      # Find appropriate detector for this method call
      detector = CallDetectors::DetectorRegistry.find_detector(receiver, method_name, args)
      
      if ENV['RAILS_OPENAPI_DEBUG'] && method_name == :partial!
        puts "   detector found: #{detector&.name}"
      end
      
      if detector
        process_detected_call(node, detector, receiver, method_name, args)
      else
        # Unknown method call, process only the arguments (not the receiver to avoid duplicates)
        args.each { |arg| process(arg) }
      end
    end

    # Process block nodes
    # @param node [Parser::AST::Node] Block node
    # @return [void]
    def on_block(node)
      send_node, args_node, body_node = node.children
      receiver, method_name, *args = send_node.children
      
      puts "🔍 DEBUG: Processing block: #{method_name}, receiver: #{receiver}" if ENV['RAILS_OPENAPI_DEBUG']
      
      # Find appropriate detector for this method call
      detector = CallDetectors::DetectorRegistry.find_detector(receiver, method_name, args)
      
      puts "🔍 DEBUG: Detector found: #{detector ? detector.class.name : 'none'}" if ENV['RAILS_OPENAPI_DEBUG']
      
      if detector
        process_detected_block(node, detector, receiver, method_name, args, body_node)
      else
        # Unknown block, process body only
        puts "🔍 DEBUG: Unknown block, processing body only" if ENV['RAILS_OPENAPI_DEBUG']
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
      if detector == RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector
        process_json_property_call(node, method_name, args)
      elsif detector == RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::ArrayCallDetector
        process_array_call(node, method_name, args)
      elsif detector == RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::PartialCallDetector
        process_partial_call(node, method_name, args)
      elsif detector == RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector
        process_cache_call(node, method_name, args)
      else
        # For meta calls (key_format, null, etc.), just process the arguments
        args.each { |arg| process(arg) }
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
      puts "🔍 DEBUG: process_detected_block called with detector: #{detector.name}, method: #{method_name}" if ENV['RAILS_OPENAPI_DEBUG']
      
      if detector == RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::ArrayCallDetector
        puts "🔍 DEBUG: Calling process_array_block" if ENV['RAILS_OPENAPI_DEBUG']
        process_array_block(node, method_name, args, body)
      elsif detector == RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector
        puts "🔍 DEBUG: Calling process_json_object_block" if ENV['RAILS_OPENAPI_DEBUG']
        process_json_object_block(node, method_name, args, body)
      elsif detector == RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector
        puts "🔍 DEBUG: Calling process_cache_block" if ENV['RAILS_OPENAPI_DEBUG']
        process_cache_block(node, method_name, args, body)
      else
        # Unknown block type, process body
        puts "🔍 DEBUG: Unknown detector: #{detector.name}, processing body" if ENV['RAILS_OPENAPI_DEBUG']
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
      
      if current_parent.is_a?(RailsOpenapiGen::AstNodes::ArrayNode)
        current_parent.add_item(property_node)
      else
        current_parent.add_property(property_node)
      end
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
      if current_parent.is_a?(RailsOpenapiGen::AstNodes::ArrayNode)
        current_parent.add_item(object_node)
      else
        current_parent.add_property(object_node)
      end
      
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
      puts "🔍 DEBUG: Processing array call: #{method_name}" if ENV['RAILS_OPENAPI_DEBUG']
      
      comment_data = extract_comment_for_node(node)
      is_conditional = in_conditional_context?
      
      # Check if this is a root array or property array
      is_root = current_parent == @root_node
      
      puts "🔍 DEBUG: Array call is_root: #{is_root}, current_parent: #{current_parent.class.name}" if ENV['RAILS_OPENAPI_DEBUG']
      
      array_node = RailsOpenapiGen::AstNodes::NodeFactory.create_array(
        property_name: is_root ? nil : 'items',
        comment_data: comment_data,
        is_conditional: is_conditional,
        is_root_array: is_root
      )
      
      if is_root
        puts "🔍 DEBUG: Replacing root node with ArrayNode" if ENV['RAILS_OPENAPI_DEBUG']
        @root_node = array_node
      else
        if current_parent.is_a?(RailsOpenapiGen::AstNodes::ArrayNode)
          current_parent.add_item(array_node)
        else
          current_parent.add_property(array_node)
        end
      end
    end

    # Process array block (json.array! do...end)
    # @param node [Parser::AST::Node] Block node
    # @param method_name [Symbol] Method name
    # @param args [Array<Parser::AST::Node>] Arguments
    # @param body [Parser::AST::Node, nil] Block body
    # @return [void]
    def process_array_block(node, method_name, args, body)
      puts "🔍 DEBUG: Processing array block: #{method_name}" if ENV['RAILS_OPENAPI_DEBUG']
      
      comment_data = extract_comment_for_node(node)
      is_conditional = in_conditional_context?
      
      # Check if this is a root array or property array
      is_root = current_parent == @root_node
      
      puts "🔍 DEBUG: Array block is_root: #{is_root}, current_parent: #{current_parent.class.name}" if ENV['RAILS_OPENAPI_DEBUG']
      
      array_node = RailsOpenapiGen::AstNodes::NodeFactory.create_array(
        property_name: is_root ? nil : 'items',
        comment_data: comment_data,
        is_conditional: is_conditional,
        is_root_array: is_root
      )
      
      puts "🔍 DEBUG: Created array node: #{array_node.class.name}" if ENV['RAILS_OPENAPI_DEBUG']
      
      if is_root
        puts "🔍 DEBUG: Replacing root node with ArrayNode (block)" if ENV['RAILS_OPENAPI_DEBUG']
        @root_node = array_node
      else
        if current_parent.is_a?(RailsOpenapiGen::AstNodes::ArrayNode)
          current_parent.add_item(array_node)
        else
          current_parent.add_property(array_node)
        end
      end
      
      # For arrays, we need to create a single object that represents the array items
      # Create an object to contain all the properties of the array items
      item_object = RailsOpenapiGen::AstNodes::NodeFactory.create_object(
        property_name: 'items',
        comment_data: nil,
        is_conditional: false
      )
      
      # Add the item object to the array
      array_node.add_item(item_object)
      
      if ENV['RAILS_OPENAPI_DEBUG']
        puts "🔍 DEBUG: Created item object for array, processing body with item context"
      end
      
      # Process block body with the item object as context
      with_context(item_object) do
        process(body) if body
      end
      
      if ENV['RAILS_OPENAPI_DEBUG']
        puts "🔍 DEBUG: After processing array block body, item has #{item_object.properties.length} properties"
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
      
      # Parse the partial if it exists
      resolved_path = resolve_partial_path(partial_path)
      if ENV['RAILS_OPENAPI_DEBUG']
        puts "🔍 Processing partial: #{partial_path}"
        puts "   Resolved path: #{resolved_path}"
        puts "   File exists: #{File.exist?(resolved_path)}"
        puts "   Current parent: #{current_parent.class.name} (#{current_parent.property_name})"
      end
      
      if File.exist?(resolved_path)
        partial_parser = self.class.new(resolved_path, parser_version: @parser_version)
        partial_root = partial_parser.parse
        
        if ENV['RAILS_OPENAPI_DEBUG']
          puts "   Parsed properties count: #{partial_root.properties.length}"
          partial_root.properties.each_with_index do |prop, i|
            puts "     #{i+1}. #{prop.property_name} (#{prop.class.name})"
          end
        end
        
        # Create a component reference for the partial
        component_name = generate_component_name(partial_path)
        
        if ENV['RAILS_OPENAPI_DEBUG']
          puts "🔍 Generated component name: '#{component_name}' from partial path: '#{partial_path}'"
        end
        
        # Store the partial schema for component generation (without processing nested partials)
        store_partial_component(component_name, partial_root)
        
        # Create a reference node
        ref_property = RailsOpenapiGen::AstNodes::NodeFactory.create_property(
          property_name: extract_property_name_from_partial(partial_path),
          comment_data: comment_data,
          is_conditional: is_conditional,
          is_component_ref: true,
          component_name: component_name
        )
        
        if current_parent.is_a?(RailsOpenapiGen::AstNodes::ArrayNode)
          current_parent.add_item(ref_property)
        else
          current_parent.add_property(ref_property)
        end
      else
        puts "⚠️  Partial file not found: #{resolved_path}" if ENV['RAILS_OPENAPI_DEBUG']
      end
    end
    
    # Resolve partial path relative to current file
    # @param partial_path [String] Partial path
    # @return [String] Resolved absolute path
    def resolve_partial_path(partial_path)
      return partial_path if partial_path.start_with?('/')
      
      # For paths like 'api/users/user', find the Rails app views directory
      if partial_path.include?('/')
        # Find the Rails views directory from current file path
        views_root = find_views_root(@file_path)
        parts = partial_path.split('/')
        file_name = parts.last
        dir_parts = parts[0..-2]
        
        # Add underscore prefix to filename if not present
        partial_file = file_name.start_with?('_') ? file_name : "_#{file_name}"
        
        File.join(views_root, *dir_parts, "#{partial_file}.json.jbuilder")
      else
        # Simple case: 'user' -> '_user.json.jbuilder' in same directory
        base_dir = File.dirname(@file_path)
        partial_file = partial_path.start_with?('_') ? partial_path : "_#{partial_path}"
        File.join(base_dir, "#{partial_file}.json.jbuilder")
      end
    end
    
    # Find the Rails views root directory
    # @param file_path [String, Pathname] Current file path
    # @return [String] Views root directory
    def find_views_root(file_path)
      file_path_str = file_path.to_s
      
      # Use the more reliable fallback method first
      if file_path_str.include?('/app/views/')
        return file_path_str.split('/app/views/').first + '/app/views'
      end
      
      # For test cases or non-standard structures, look for a pattern like:
      # test_views/api/users/orders/index.json.jbuilder -> test_views
      # by finding the deepest directory that contains the template structure
      path_parts = file_path_str.split('/')
      
      # Look for common view directory patterns
      view_indicators = ['views', 'app', 'test_views']
      
      view_indicators.each do |indicator|
        if path_parts.include?(indicator)
          indicator_index = path_parts.index(indicator)
          # If this is a views-like directory, use it as root
          if indicator == 'views' || indicator == 'test_views'
            return path_parts[0..indicator_index].join('/')
          elsif indicator == 'app'
            # For app directory, assume app/views structure
            return path_parts[0..indicator_index].join('/') + '/views'
          end
        end
      end
      
      # Alternative: traverse up the directory tree looking for views
      current_dir = File.dirname(file_path_str)
      
      while current_dir != '/' && current_dir != '.'
        if File.basename(current_dir) == 'views' || File.basename(current_dir) == 'test_views'
          return current_dir
        end
        current_dir = File.dirname(current_dir)
      end
      
      # Final fallback
      File.dirname(file_path_str)
    end

    # Process cache call (json.cache!)
    # @param node [Parser::AST::Node] Method call node
    # @param method_name [Symbol] Method name
    # @param args [Array<Parser::AST::Node>] Arguments
    # @return [void]
    def process_cache_call(node, method_name, args)
      # Cache calls don't affect schema structure, just process the arguments
      args.each { |arg| process(arg) }
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
          conditional: parsed_comment[:conditional],
          format: parsed_comment[:format],
          example: parsed_comment[:example]
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

    # Generate component name from partial path
    # @param partial_path [String] Partial path (e.g., 'api/users/professional_experience')
    # @return [String] Component name (e.g., 'ApiUsersProfessionalExperience')
    def generate_component_name(partial_path)
      # Split path into parts and clean each part
      path_parts = partial_path.split('/')
      
      # Clean each part: remove underscore prefix, convert to PascalCase
      clean_parts = path_parts.map do |part|
        # Remove leading underscore if present
        cleaned = part.sub(/^_/, '')
        
        # Convert snake_case to PascalCase
        camelized = cleaned.split('_').map do |word|
          # Keep only alphanumeric characters and capitalize
          word_cleaned = word.gsub(/[^a-zA-Z0-9]/, '')
          word_cleaned.capitalize
        end.join('')
        
        camelized
      end
      
      # Join parts to create component name
      component_name = clean_parts.join('')
      
      # Ensure it starts with a capital letter and is not empty
      component_name.empty? ? 'Component' : component_name
    end

    # Store partial component for later component generation
    # @param component_name [String] Component name
    # @param partial_root [RailsOpenapiGen::AstNodes::BaseNode] Parsed partial root
    # @return [void]
    def store_partial_component(component_name, partial_root)
      @partial_components[component_name] = partial_root
      puts "📦 Stored component: #{component_name}" if ENV['RAILS_OPENAPI_DEBUG']
    end

    # Extract property name from partial path
    # @param partial_path [String] Partial path (e.g., 'api/users/user')
    # @return [String] Property name (e.g., 'user')
    def extract_property_name_from_partial(partial_path)
      filename = File.basename(partial_path)
      filename.sub(/^_/, '').downcase
    end

    # Determine if we should create a component for this partial
    # Only create components for top-level partials to avoid component-to-component references
    # @param partial_path [String] Partial path
    # @return [Boolean] True if should create component
    def should_create_component?(partial_path)
      # Only create components for main partials (like users/user, posts/post)
      # Not for nested model partials (like users/model/address)
      !partial_path.include?('/model/')
    end

    # Inline expand nested partials within a component
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Node to process
    # @return [RailsOpenapiGen::AstNodes::BaseNode] Node with expanded partials
    def inline_expand_nested_partials(node)
      case node
      when RailsOpenapiGen::AstNodes::ObjectNode
        expanded_node = node.dup
        expanded_node.instance_variable_set(:@properties, [])
        
        node.properties.each do |property|
          if property.is_a?(RailsOpenapiGen::AstNodes::PropertyNode) && property.is_component_ref
            # Inline expand component references within components
            expanded_property = expand_component_to_inline_object(property)
            expanded_node.add_property(expanded_property) if expanded_property
          else
            # Recursively process nested nodes
            expanded_property = inline_expand_nested_partials(property)
            expanded_node.add_property(expanded_property)
          end
        end
        
        expanded_node
      when RailsOpenapiGen::AstNodes::ArrayNode
        expanded_node = node.dup
        expanded_node.instance_variable_set(:@items, [])
        
        node.items.each do |item|
          expanded_item = inline_expand_nested_partials(item)
          expanded_node.add_item(expanded_item)
        end
        
        expanded_node
      else
        node
      end
    end

    # Expand a component reference to an inline object
    # @param component_ref_property [RailsOpenapiGen::AstNodes::PropertyNode] Component reference property
    # @return [RailsOpenapiGen::AstNodes::ObjectNode, nil] Expanded object or nil if not found
    def expand_component_to_inline_object(component_ref_property)
      # Find the partial file based on the component name
      partial_path = find_partial_path_from_component_name(component_ref_property.component_name)
      return nil unless partial_path
      
      resolved_path = resolve_partial_path(partial_path)
      return nil unless File.exist?(resolved_path)
      
      # Parse the partial
      partial_parser = self.class.new(resolved_path, parser_version: @parser_version)
      partial_root = partial_parser.parse
      
      # Create an object node with the partial's properties
      expanded_object = RailsOpenapiGen::AstNodes::NodeFactory.create_object(
        property_name: component_ref_property.property_name,
        comment_data: component_ref_property.comment_data,
        is_conditional: component_ref_property.is_conditional
      )
      
      # Add all properties from the partial (recursively expand any nested partials)
      partial_root.properties.each do |property|
        expanded_property = inline_expand_nested_partials(property)
        expanded_object.add_property(expanded_property)
      end
      
      expanded_object
    end

    # Inline expand a partial into the current context
    # @param partial_root [RailsOpenapiGen::AstNodes::BaseNode] Parsed partial root
    # @param property_name [String] Property name for the partial
    # @param comment_data [RailsOpenapiGen::AstNodes::CommentData] Comment data
    # @param is_conditional [Boolean] Whether the partial is conditional
    # @return [void]
    def inline_expand_partial(partial_root, property_name, comment_data, is_conditional)
      # Create an object to wrap the partial's properties
      wrapper_object = RailsOpenapiGen::AstNodes::NodeFactory.create_object(
        property_name: property_name,
        comment_data: comment_data,
        is_conditional: is_conditional
      )
      
      # Add all properties from the partial
      partial_root.properties.each do |property|
        expanded_property = inline_expand_nested_partials(property)
        wrapper_object.add_property(expanded_property)
      end
      
      # Add to current parent
      if current_parent.is_a?(RailsOpenapiGen::AstNodes::ArrayNode)
        current_parent.add_item(wrapper_object)
      else
        current_parent.add_property(wrapper_object)
      end
    end

    # Expand partial references inline to avoid component-to-component references
    # @param node [RailsOpenapiGen::AstNodes::BaseNode] Node to process
    # @param processed_partials [Set] Set of already processed partial paths to avoid cycles
    # @return [RailsOpenapiGen::AstNodes::BaseNode] Node with expanded partials
    def expand_partials_inline(node, processed_partials = Set.new)
      case node
      when RailsOpenapiGen::AstNodes::ObjectNode
        expanded_node = node.dup
        expanded_node.instance_variable_set(:@properties, [])
        
        node.properties.each do |property|
          if property.is_a?(RailsOpenapiGen::AstNodes::PropertyNode) && property.is_component_ref
            # Expand the referenced component inline
            expanded_property = expand_component_reference_inline(property, processed_partials)
            expanded_node.add_property(expanded_property) if expanded_property
          else
            # Recursively expand nested nodes
            expanded_property = expand_partials_inline(property, processed_partials)
            expanded_node.add_property(expanded_property)
          end
        end
        
        expanded_node
      when RailsOpenapiGen::AstNodes::ArrayNode
        expanded_node = node.dup
        expanded_node.instance_variable_set(:@items, [])
        
        node.items.each do |item|
          expanded_item = expand_partials_inline(item, processed_partials)
          expanded_node.add_item(expanded_item)
        end
        
        expanded_node
      when RailsOpenapiGen::AstNodes::PropertyNode
        if node.is_component_ref
          # This shouldn't happen at the top level, but handle it just in case
          expand_component_reference_inline(node, processed_partials)
        else
          node
        end
      else
        node
      end
    end

    # Expand a component reference inline by finding and parsing the referenced partial
    # @param component_ref_property [RailsOpenapiGen::AstNodes::PropertyNode] Component reference property
    # @param processed_partials [Set] Set of already processed partial paths to avoid cycles
    # @return [RailsOpenapiGen::AstNodes::BaseNode, nil] Expanded node or nil if not found
    def expand_component_reference_inline(component_ref_property, processed_partials)
      # Find the partial file based on the component name
      partial_path = find_partial_path_from_component_name(component_ref_property.component_name)
      return nil unless partial_path
      
      # Check for circular reference
      if processed_partials.include?(partial_path)
        puts "⚠️  Circular reference detected for partial: #{partial_path}" if ENV['RAILS_OPENAPI_DEBUG']
        return create_placeholder_object(component_ref_property)
      end
      
      resolved_path = resolve_partial_path(partial_path)
      return nil unless File.exist?(resolved_path)
      
      # Add to processed set to avoid cycles
      new_processed = processed_partials.dup
      new_processed.add(partial_path)
      
      # Parse the partial without storing it as a component
      partial_parser = self.class.new(resolved_path, parser_version: @parser_version)
      partial_root = partial_parser.parse
      
      # Create an object node with the partial's properties
      expanded_object = RailsOpenapiGen::AstNodes::NodeFactory.create_object(
        property_name: component_ref_property.property_name,
        comment_data: component_ref_property.comment_data,
        is_conditional: component_ref_property.is_conditional
      )
      
      # Add all properties from the partial
      partial_root.properties.each do |property|
        expanded_property = expand_partials_inline(property, new_processed)
        expanded_object.add_property(expanded_property)
      end
      
      expanded_object
    end

    # Create a placeholder object for circular references
    # @param component_ref_property [RailsOpenapiGen::AstNodes::PropertyNode] Component reference property
    # @return [RailsOpenapiGen::AstNodes::ObjectNode] Placeholder object
    def create_placeholder_object(component_ref_property)
      RailsOpenapiGen::AstNodes::NodeFactory.create_object(
        property_name: component_ref_property.property_name,
        comment_data: nil,
        is_conditional: component_ref_property.is_conditional
      )
    end

    # Find partial path from component name (reverse of generate_component_name)
    # @param component_name [String] Component name (e.g., 'ApiUsersUser')
    # @return [String, nil] Partial path (e.g., 'api/users/user') or nil if not found
    def find_partial_path_from_component_name(component_name)
      # This is a simplified reverse mapping
      # In practice, you might want to store this mapping or use a more sophisticated approach
      
      # Convert PascalCase back to snake_case path
      # ApiUsersUser -> api/users/user
      parts = component_name.scan(/[A-Z][a-z]*/)
      return nil if parts.empty?
      
      snake_case_parts = parts.map(&:downcase)
      snake_case_parts.join('/')
    end
  end
end