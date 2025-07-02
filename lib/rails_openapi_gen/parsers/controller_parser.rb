# frozen_string_literal: true

require "parser/current"

module RailsOpenapiGen
  module Parsers
    class ControllerParser
      attr_reader :route

      def initialize(route)
        @route = route
      end

      def parse
        controller_path = find_controller_file
        return {} unless controller_path

        content = File.read(controller_path)
        ast = Parser::CurrentRuby.parse(content)
        
        action_node = find_action_method(ast)
        return {} unless action_node

        jbuilder_path = extract_jbuilder_path(action_node)
        parameters = extract_parameters_from_comments(content, action_node)
        
        {
          controller_path: controller_path,
          jbuilder_path: jbuilder_path,
          action: route[:action],
          parameters: parameters
        }
      end

      private

      def find_controller_file
        controller_name = "#{route[:controller]}_controller"
        possible_paths = [
          Rails.root.join("app", "controllers", "#{controller_name}.rb")
        ]
        
        # Handle nested controllers
        if route[:controller].include?("/")
          parts = route[:controller].split("/")
          nested_path = Rails.root.join("app", "controllers", *parts[0..-2], "#{parts.last}_controller.rb")
          possible_paths << nested_path
        end
        
        possible_paths.find { |path| File.exist?(path) }
      end

      def find_action_method(ast)
        return nil unless ast

        processor = ActionMethodProcessor.new(route[:action])
        processor.process(ast)
        processor.action_node
      end

      def extract_jbuilder_path(action_node)
        return nil unless action_node

        processor = JbuilderPathProcessor.new(route[:controller], route[:action])
        processor.process(action_node)
        
        # If no explicit render call found, check for default template
        jbuilder_path = processor.jbuilder_path
        unless jbuilder_path
          jbuilder_path = find_default_jbuilder_template
        end
        
        jbuilder_path
      end
      
      def find_default_jbuilder_template
        # Rails convention: app/views/{controller}/{action}.json.jbuilder
        template_path = Rails.root.join("app", "views", route[:controller], "#{route[:action]}.json.jbuilder")
        File.exist?(template_path) ? template_path.to_s : nil
      end

      def extract_parameters_from_comments(content, action_node)
        return {} unless action_node

        lines = content.lines
        action_line = action_node.location.line - 1 # Convert to 0-based index
        
        # Look for comments before the action method
        parameters = {
          path_parameters: [],
          query_parameters: [],
          body_parameters: []
        }
        
        comment_parser = RailsOpenapiGen::Parsers::CommentParser.new
        
        # Scan backwards from the action line to find comments
        (action_line - 1).downto(0) do |line_index|
          line = lines[line_index].strip
          
          # Stop if we encounter a non-comment line that's not empty
          break if !line.empty? && !line.start_with?('#')
          
          next if line.empty? || !line.include?('@openapi')
          
          parsed = comment_parser.parse(line)
          next unless parsed
          
          if parsed[:parameter]
            parameters[:path_parameters] << parsed[:parameter]
          elsif parsed[:query_parameter]
            parameters[:query_parameters] << parsed[:query_parameter]
          elsif parsed[:body_parameter]
            parameters[:body_parameters] << parsed[:body_parameter]
          end
        end
        
        parameters
      end

      class ActionMethodProcessor < Parser::AST::Processor
        attr_reader :action_node

        def initialize(action_name)
          @action_name = action_name.to_sym
          @action_node = nil
        end

        def on_def(node)
          method_name = node.children[0]
          @action_node = node if method_name == @action_name
          super
        end
      end

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