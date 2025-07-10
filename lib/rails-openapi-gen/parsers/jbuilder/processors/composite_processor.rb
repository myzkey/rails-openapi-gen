# frozen_string_literal: true

require_relative 'base_processor'
require_relative 'array_processor'
require_relative 'object_processor'
require_relative 'property_processor'
require_relative 'partial_processor'
require_relative '../call_detectors'

module RailsOpenapiGen::Parsers::Jbuilder::Processors
  class CompositeProcessor < BaseProcessor
          # Alias for shorter reference to call detectors
          CallDetectors = RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
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

            # Skip Jbuilder helper methods - they are not JSON properties
            if CallDetectors::CacheCallDetector.cache_call?(receiver, method_name) ||
               CallDetectors::CacheCallDetector.cache_if_call?(receiver, method_name) ||
               CallDetectors::KeyFormatDetector.key_format?(receiver, method_name) ||
               CallDetectors::NullHandlingDetector.null_handling?(receiver, method_name) ||
               CallDetectors::ObjectManipulationDetector.object_manipulation?(receiver, method_name)
              super(node)
            elsif CallDetectors::ArrayCallDetector.array_call?(receiver, method_name)
              @array_processor.on_send(node)
              merge_processor_results(@array_processor)
            elsif CallDetectors::PartialCallDetector.partial_call?(receiver, method_name)
              @partial_processor.on_send(node)
              merge_processor_results(@partial_processor)
            elsif CallDetectors::JsonCallDetector.json_property?(receiver, method_name)
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

            if CallDetectors::CacheCallDetector.cache_call?(receiver, method_name)
              # This is json.cache! or json.cache_if! block - just process the block contents
              process_node(body) if body
            elsif CallDetectors::CacheCallDetector.cache_if_call?(receiver, method_name)
              # This is json.cache! or json.cache_if! block - just process the block contents
              process_node(body) if body
            elsif CallDetectors::JsonCallDetector.json_property?(receiver, method_name) && method_name != :array!
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
            elsif CallDetectors::ArrayCallDetector.array_call?(receiver, method_name)
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
            # Use getter methods to ensure arrays exist
            properties.concat(processor.properties)
            partials.concat(processor.partials)

            # Clear the sub-processor's results by calling private clear methods
            processor.send(:clear_results)
          end
  end
end
