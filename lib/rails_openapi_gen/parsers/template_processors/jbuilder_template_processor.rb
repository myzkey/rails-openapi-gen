# frozen_string_literal: true

require "parser/current"
require_relative 'response_template_processor'

module RailsOpenapiGen
  module Parsers
    module TemplateProcessors
      class JbuilderTemplateProcessor
        include ResponseTemplateProcessor

        def initialize(controller, action)
          @controller = controller
          @action = action
        end

        def extract_template_path(action_node, route)
          return nil unless action_node

          processor = JbuilderPathProcessor.new(route[:controller], route[:action])
          processor.process(action_node)
          processor.jbuilder_path
        end

        def find_default_template(route)
          template_path = Rails.root.join("app", "views", route[:controller], "#{route[:action]}.json.jbuilder")
          File.exist?(template_path) ? template_path.to_s : nil
        end

        private

        class JbuilderPathProcessor < Parser::AST::Processor
          attr_reader :jbuilder_path

          def initialize(controller, action)
            @controller = controller
            @action = action
            @jbuilder_path = nil
          end

          def on_send(node)
            if render_call?(node)
              extract_render_target(node)
            end
            super
          end

          private

          def render_call?(node)
            receiver, method_name = node.children[0..1]
            receiver.nil? && method_name == :render
          end

          def extract_render_target(node)
            args = node.children[2..-1]
            
            if args.empty?
              @jbuilder_path = default_jbuilder_path
            elsif args.first.type == :hash
              parse_render_options(args.first)
            elsif args.first.type == :str || args.first.type == :sym
              template = args.first.children.first.to_s
              @jbuilder_path = Rails.root.join("app", "views", @controller, "#{template}.json.jbuilder")
            end
          end

          def parse_render_options(hash_node)
            hash_node.children.each do |pair|
              key_node, value_node = pair.children
              next unless key_node.type == :sym

              case key_node.children.first
              when :json
                @jbuilder_path = default_jbuilder_path
              when :template
                template = value_node.children.first
                @jbuilder_path = Rails.root.join("app", "views", template.gsub("/", File::SEPARATOR) + ".json.jbuilder")
              end
            end
          end

          def default_jbuilder_path
            Rails.root.join("app", "views", @controller, "#{@action}.json.jbuilder")
          end
        end
      end
    end
  end
end