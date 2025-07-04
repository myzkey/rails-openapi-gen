# frozen_string_literal: true

require "parser/current"

module RailsOpenapiGen
  module Parsers
    class ControllerParser
      attr_reader :route

      # Initializes controller parser with route information
      # @param route [Hash] Route hash containing controller and action info
      def initialize(route)
        @route = route
      end

      # Parses controller to find action method and Jbuilder template
      # @return [Hash] Controller info including paths and parameters
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

      # Finds the controller file path based on route information
      # @return [String, nil] Path to controller file or nil if not found
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

      # Finds action method node in the AST
      # @param ast [Parser::AST::Node] Controller AST
      # @return [Parser::AST::Node, nil] Action method node or nil
      def find_action_method(ast)
        return nil unless ast

        processor = ActionMethodProcessor.new(route[:action])
        processor.process(ast)
        processor.action_node
      end

      # Extracts Jbuilder template path from action method
      # @param action_node [Parser::AST::Node] Action method node
      # @return [String, nil] Path to Jbuilder template or nil
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
      
      # Finds default Jbuilder template following Rails conventions
      # @return [String, nil] Path to default template or nil
      def find_default_jbuilder_template
        # Rails convention: app/views/{controller}/{action}.json.jbuilder
        template_path = Rails.root.join("app", "views", route[:controller], "#{route[:action]}.json.jbuilder")
        File.exist?(template_path) ? template_path.to_s : nil
      end

      # Extracts parameter definitions from comments above action method
      # @param content [String] Controller file content
      # @param action_node [Parser::AST::Node] Action method node
      # @return [Hash] Parameters hash with path, query, and body parameters
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

        # Initializes processor to find specific action method
        # @param action_name [String, Symbol] Name of action to find
        def initialize(action_name)
          @action_name = action_name.to_sym
          @action_node = nil
        end

        # Processes method definition nodes
        # @param node [Parser::AST::Node] Method definition node
        # @return [void]
        def on_def(node)
          method_name = node.children[0]
          @action_node = node if method_name == @action_name
          super
        end
      end

      class JbuilderPathProcessor < Parser::AST::Processor
        attr_reader :jbuilder_path

        # Initializes processor to extract Jbuilder path from render calls
        # @param controller [String] Controller name
        # @param action [String] Action name
        def initialize(controller, action)
          @controller = controller
          @action = action
          @jbuilder_path = nil
        end

        # Processes method call nodes to find render calls
        # @param node [Parser::AST::Node] Method call node
        # @return [void]
        def on_send(node)
          if render_call?(node)
            extract_render_target(node)
          end
          super
        end

        private

        # Checks if node is a render method call
        # @param node [Parser::AST::Node] Node to check
        # @return [Boolean] True if render call
        def render_call?(node)
          receiver, method_name = node.children[0..1]
          receiver.nil? && method_name == :render
        end

        # Extracts render target from render method call
        # @param node [Parser::AST::Node] Render call node
        # @return [void]
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

        # Parses render options hash to find template
        # @param hash_node [Parser::AST::Node] Hash node with render options
        # @return [void]
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

        # Returns default Jbuilder template path
        # @return [Pathname] Default template path
        def default_jbuilder_path
          Rails.root.join("app", "views", @controller, "#{@action}.json.jbuilder")
        end
      end
    end
  end
end