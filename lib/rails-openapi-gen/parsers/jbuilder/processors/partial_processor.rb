# frozen_string_literal: true

require_relative 'base_processor'
require_relative '../call_detectors'

module RailsOpenapiGen::Parsers::Jbuilder::Processors
  class PartialProcessor < BaseProcessor
          # Alias for shorter reference to call detectors
          CallDetectors = RailsOpenapiGen::Parsers::Jbuilder::CallDetectors
          # Processes method call nodes for partial render calls
          # @param node [Parser::AST::Node] Method call node
          # @return [void]
          def on_send(node)
            receiver, method_name, *args = node.children

            process_partial(args) if CallDetectors::PartialCallDetector.partial_call?(receiver, method_name)

            super(node)
          end

          private

          # Processes partial render calls to track dependencies
          # @param args [Array] Partial call arguments
          # @return [void]
          def process_partial(args)
            return if args.empty?

            partial_name = extract_partial_name(args)
            return unless partial_name

            partial_path = resolve_partial_path(partial_name)
            @partials << partial_path if partial_path
          end

          # Extracts partial name from arguments (handles both string and hash syntax)
          # @param args [Array] Partial call arguments
          # @return [String, nil] Partial name or nil
          def extract_partial_name(args)
            first_arg = args.first
            
            # Handle simple string case: json.partial! 'path/to/partial'
            if first_arg.type == :str
              return first_arg.children.first
            end
            
            # Handle hash case: json.partial! partial: 'path/to/partial', locals: {...}
            if first_arg.type == :hash
              first_arg.children.each do |pair|
                next unless pair.type == :pair
                
                key, value = pair.children
                if key.type == :sym && key.children.first == :partial && value.type == :str
                  return value.children.first
                end
              end
            end
            
            nil
          end
  end
end
