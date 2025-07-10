# frozen_string_literal: true

require_relative 'base_processor'
require_relative 'array_processor'
require_relative 'object_processor'
require_relative 'property_processor'
require_relative 'partial_processor'
require_relative '../call_detectors/cache_call_detector'
require_relative '../call_detectors/key_format_detector'
require_relative '../call_detectors/null_handling_detector'
require_relative '../call_detectors/object_manipulation_detector'
require_relative '../call_detectors/array_call_detector'
require_relative '../call_detectors/partial_call_detector'
require_relative '../call_detectors/json_call_detector'

module RailsOpenapiGen
  module Parsers
    module Jbuilder
      module Processors
        class CompositeProcessor < BaseProcessor
          # Initializes composite processor with all sub-processors
          # @param file_path [String] Path to current file
          # @param property_parser [PropertyCommentParser] Parser for property comments
          def initialize(file_path, property_parser)
            super(file_path, property_parser)

            # Initialize sub-processors
            @array_processor = ArrayProcessor.new(file_path, property_parser)
            @object_processor = ObjectProcessor.new(file_path, property_parser)
            @property_processor = PropertyProcessor.new(file_path, property_parser)
            @partial_processor = PartialProcessor.new(file_path, property_parser)
          end

          # Processes method call nodes by delegating to appropriate processors
          # @param node [Parser::AST::Node] Method call node
          # @return [void]
          def on_send(node)
            receiver, method_name, = node.children

            if Jbuilder::CallDetectors::CacheCallDetector.cache_call?(receiver, method_name)
              super(node)
            elsif Jbuilder::CallDetectors::CacheCallDetector.cache_if_call?(receiver, method_name)
              super(node)
            elsif Jbuilder::CallDetectors::KeyFormatDetector.key_format?(receiver, method_name)
              super(node)
            elsif Jbuilder::CallDetectors::NullHandlingDetector.null_handling?(receiver, method_name)
              super(node)
            elsif Jbuilder::CallDetectors::ObjectManipulationDetector.object_manipulation?(receiver, method_name)
              # Skip Jbuilder helper methods - they are not JSON properties
              super(node)
            elsif Jbuilder::CallDetectors::ArrayCallDetector.array_call?(receiver, method_name)
              @array_processor.on_send(node)
              merge_processor_results(@array_processor)
            elsif Jbuilder::CallDetectors::PartialCallDetector.partial_call?(receiver, method_name)
              @partial_processor.on_send(node)
              merge_processor_results(@partial_processor)
            elsif Jbuilder::CallDetectors::JsonCallDetector.json_property?(receiver, method_name)
              @property_processor.on_send(node)
              merge_processor_results(@property_processor)
            end

            super(node)
          end

          # Processes block nodes by delegating to appropriate processors
          # @param node [Parser::AST::Node] Block node
          # @return [void]
          def on_block(node)
            send_node, args_node, body = node.children
            receiver, method_name, = send_node.children

            if Jbuilder::CallDetectors::CacheCallDetector.cache_call?(receiver, method_name)
              # This is json.cache! or json.cache_if! block - just process the block contents
              process_node(body) if body
            elsif Jbuilder::CallDetectors::CacheCallDetector.cache_if_call?(receiver, method_name)
              # This is json.cache! or json.cache_if! block - just process the block contents
              process_node(body) if body
            elsif Jbuilder::CallDetectors::JsonCallDetector.json_property?(receiver, method_name) && method_name != :array!
              # Check if this is an array iteration block (has block arguments)
              if args_node && args_node.type == :args && args_node.children.any?
                # This is an array iteration block like json.tags @tags do |tag|
                @array_processor.on_block(node)
                merge_processor_results(@array_processor)
              else
                # This is a nested object block like json.profile do
                @object_processor.on_block(node)
                merge_processor_results(@object_processor)
              end
            elsif Jbuilder::CallDetectors::ArrayCallDetector.array_call?(receiver, method_name)
              # This is json.array! block
              @array_processor.on_block(node)
              merge_processor_results(@array_processor)
            else
              super(node)
            end
          end

          private

          # Merges results from a sub-processor into this processor
          # @param processor [BaseProcessor] Sub-processor to merge results from
          # @return [void]
          def merge_processor_results(processor)
            @properties.concat(processor.properties)
            @partials.concat(processor.partials)

            # Clear the sub-processor's results to avoid duplication
            processor.properties.clear
            processor.partials.clear
          end
        end
      end
    end
  end
end
