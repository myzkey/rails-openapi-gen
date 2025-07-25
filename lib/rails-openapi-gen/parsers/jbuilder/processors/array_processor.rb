# frozen_string_literal: true

require_relative 'base_processor'
require_relative '../call_detectors'

module RailsOpenapiGen::Parsers::Jbuilder::Processors
  class ArrayProcessor < BaseProcessor
    # Alias for shorter reference to call detectors
    CallDetectors = RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
    # Alias for shorter reference to JbuilderParser
    JbuilderParser = RailsOpenapiGen::Parsers::Jbuilder::JbuilderParser
    # Lazy load CompositeProcessor to avoid circular dependency
    def self.composite_processor_class
      RailsOpenapiGen::Parsers::Jbuilder::Processors::CompositeProcessor
    end

    # Processes method call nodes for array-related operations
    # @param node [Parser::AST::Node] Method call node
    # @return [void]
    def on_send(node)
      receiver, method_name, *args = node.children

      if CallDetectors::ArrayCallDetector.array_call?(receiver, method_name)
        # Check if this is an array with partial
        if args.any? && args.any? do |arg|
             arg.type == :hash && CallDetectors::ArrayCallDetector.has_partial_key?(arg)
           end
          process_array_with_partial(node, args)
        else
          process_array_property(node)
        end
      end

      super
    end

    # Processes block nodes for array iterations
    # @param node [Parser::AST::Node] Block node
    # @return [void]
    def on_block(node)
      send_node, args_node, = node.children
      receiver, method_name, = send_node.children

      if CallDetectors::ArrayCallDetector.array_call?(receiver, method_name)
        # This is json.array! block
        process_array_block(node)
      elsif CallDetectors::JsonCallDetector.json_property?(receiver, method_name) && method_name != :array!
        # Check if this is an array iteration block (has block arguments)
        if args_node && args_node.type == :args && args_node.children.any?
          # This is an array iteration block like json.tags @tags do |tag|
          process_array_iteration_block(node, method_name.to_s)
        else
          super
        end
      else
        super
      end
    end

    private

    # Processes json.array! block to create array schema with item properties
    # @param node [Parser::AST::Node] Array block node
    # @return [void]
    def process_array_block(node)
      _, _, body = node.children
      comment_data = find_comment_for_node(node)

      # Save current context
      previous_properties = properties.dup
      previous_partials = partials.dup

      # Create a temporary properties array for array items
      @properties = []
      @partials = []
      push_block(:array)

      # Process the block contents using CompositeProcessor
      if body
        # Create a CompositeProcessor to handle all types of calls within the block
        composite_processor = self.class.composite_processor_class.new(@file_path, @property_parser)
        composite_processor.process(body)

        # Merge results from the composite processor
        @properties.concat(composite_processor.properties)
        @partials.concat(composite_processor.partials)
      end

      # Collect item properties
      item_properties = properties.dup

      # Process any partials found in this block
      puts "🔍 DEBUG: Found #{partials.size} partials in array block" if ENV['RAILS_OPENAPI_DEBUG']
      partials.each do |partial_path|
        puts "🔍 DEBUG: Processing partial: #{partial_path}" if ENV['RAILS_OPENAPI_DEBUG']
        if File.exist?(partial_path)
          partial_properties = parse_partial_for_nested_object(partial_path)
          puts "🔍 DEBUG: Partial properties: #{partial_properties.size}" if ENV['RAILS_OPENAPI_DEBUG']
          item_properties.concat(partial_properties)
        elsif ENV['RAILS_OPENAPI_DEBUG']
          puts "🔍 DEBUG: Partial file not found: #{partial_path}"
        end
      end

      # Restore context
      @properties = previous_properties
      @partials = previous_partials
      pop_block

      # Convert item properties to structured nodes if needed
      structured_item_properties = item_properties.map do |item|
        if item.is_a?(Hash)
          RailsOpenapiGen::AstNodes::PropertyNodeFactory.from_hash(item)
        else
          item
        end
      end

      # Create comment data
      comment_obj = if comment_data
                      RailsOpenapiGen::AstNodes::CommentData.new(
                        type: comment_data[:type] || 'array',
                        items: comment_data[:items] || { type: 'object' }
                      )
                    else
                      RailsOpenapiGen::AstNodes::CommentData.new(type: 'array', items: { type: 'object' })
                    end

      # Create array root node
      array_root_node = RailsOpenapiGen::AstNodes::PropertyNodeFactory.create_array_root(
        comment_data: comment_obj,
        array_item_properties: structured_item_properties
      )

      add_property(array_root_node)
    end

    # Processes json.array! calls to create array schema
    # @param node [Parser::AST::Node] Array call node
    # @return [void]
    def process_array_property(node)
      comment_data = find_comment_for_node(node)

      # Mark this as an array root
      property_info = {
        node_type: 'array',
        property: 'items', # Special property to indicate array items
        comment_data: comment_data || { type: 'array', items: { type: 'object' } },
        is_array_root: true
      }

      add_property(property_info)
    end

    # Processes json.array! with partial rendering
    # @param node [Parser::AST::Node] Array call node
    # @param args [Array] Array call arguments
    # @return [void]
    def process_array_with_partial(node, args)
      # Extract partial path from the hash arguments
      partial_path = nil
      args.each do |arg|
        next unless arg.type == :hash

        arg.children.each do |pair|
          next unless pair.type == :pair

          key, value = pair.children
          if key.type == :sym && key.children.first == :partial && value.type == :str
            partial_path = value.children.first
            break
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
            node_type: 'array',
            property: 'items',
            comment_data: { type: 'array' },
            is_array_root: true,
            array_item_properties: partial_result[:properties]
          }

          add_property(property_info)
        else
          # Fallback to regular array processing
          process_array_property(node)
        end
      else
        # Fallback to regular array processing
        process_array_property(node)
      end
    end

    # Processes array iteration blocks (e.g., json.tags @tags do |tag|)
    # @param node [Parser::AST::Node] Block node
    # @param property_name [String] Array property name
    # @return [void]
    def process_array_iteration_block(node, property_name)
      comment_data = find_comment_for_node(node)

      # Save current context
      previous_properties = properties.dup
      previous_partials = partials.dup

      # Create a temporary properties array for array items
      @properties = []
      @partials = []
      push_block(:array)

      # Process the block contents using CompositeProcessor
      _, _args, body = node.children
      if body
        # Create a CompositeProcessor to handle all types of calls within the block
        composite_processor = self.class.composite_processor_class.new(@file_path, @property_parser)
        composite_processor.process(body)

        # Merge results from the composite processor
        @properties.concat(composite_processor.properties)
        @partials.concat(composite_processor.partials)
      end

      # Collect item properties
      item_properties = properties.dup
      puts "🔍 DEBUG: Array block processed, item_properties size: #{item_properties.size}" if ENV['RAILS_OPENAPI_DEBUG']

      # Process any partials found in this block
      puts "🔍 DEBUG: Found #{partials.size} partials in array block" if ENV['RAILS_OPENAPI_DEBUG']
      partials.each do |partial_path|
        puts "🔍 DEBUG: Processing partial: #{partial_path}" if ENV['RAILS_OPENAPI_DEBUG']
        if File.exist?(partial_path)
          partial_properties = parse_partial_for_nested_object(partial_path)
          puts "🔍 DEBUG: Partial properties: #{partial_properties.size}" if ENV['RAILS_OPENAPI_DEBUG']
          item_properties.concat(partial_properties)
        elsif ENV['RAILS_OPENAPI_DEBUG']
          puts "🔍 DEBUG: Partial file not found: #{partial_path}"
        end
      end

      # Restore context
      @properties = previous_properties
      @partials = previous_partials
      pop_block

      # Build array schema with items
      property_info = {
        node_type: 'property',
        property: property_name,
        comment_data: comment_data || { type: 'array' },
        is_array: true,
        array_item_properties: item_properties
      }

      add_property(property_info)
    end
  end
end
