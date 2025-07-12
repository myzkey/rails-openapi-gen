# frozen_string_literal: true

require "parser/current"
require_relative '../template_processors'

module RailsOpenapiGen::Parsers::TemplateProcessors
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
        render_options = extract_render_hash_options(hash_node)
        
        if render_options[:json]
          @jbuilder_path = default_jbuilder_path
        elsif render_options[:template]
          template_path = render_options[:template]
          formats = render_options[:formats] || :json
          handlers = render_options[:handlers] || :jbuilder
          
          # Build full template path with format and handler
          full_template_path = build_template_path(template_path, formats, handlers)
          @jbuilder_path = Rails.root.join("app", "views", "#{full_template_path}")
        end
      end

      def extract_render_hash_options(hash_node)
        options = {}
        
        hash_node.children.each do |pair|
          key_node, value_node = pair.children
          next unless key_node.type == :sym
          
          key = key_node.children.first
          value = extract_node_value(value_node)
          
          options[key] = value
        end
        
        options
      end

      def extract_node_value(node)
        case node.type
        when :str, :sym
          node.children.first
        when :true
          true
        when :false
          false
        else
          node.children.first
        end
      end

      def build_template_path(template, formats, handlers)
        # Handle different format specifications
        format_str = case formats
                    when Symbol
                      formats.to_s
                    when String
                      formats
                    else
                      "json"
                    end
        
        # Handle different handler specifications  
        handler_str = case handlers
                     when Symbol
                       handlers.to_s
                     when String
                       handlers
                     else
                       "jbuilder"
                     end
        
        # Build the path: template.format.handler
        "#{template.gsub('/', File::SEPARATOR)}.#{format_str}.#{handler_str}"
      end

      def default_jbuilder_path
        Rails.root.join("app", "views", @controller, "#{@action}.json.jbuilder")
      end
    end
  end
end