# frozen_string_literal: true

require_relative "base_processor"
require_relative "../call_detectors/partial_call_detector"

module RailsOpenapiGen
  module Parsers
    module Jbuilder
      module Processors
        class PartialProcessor < BaseProcessor
          # Processes method call nodes for partial render calls
          # @param node [Parser::AST::Node] Method call node
          # @return [void]
          def on_send(node)
            receiver, method_name, *args = node.children
            
            if Jbuilder::CallDetectors::PartialCallDetector.partial_call?(receiver, method_name)
              process_partial(args)
            end
            
            super
          end

          private

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
        end
      end
    end
  end
end