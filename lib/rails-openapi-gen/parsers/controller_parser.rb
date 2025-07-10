# frozen_string_literal: true

require "parser/current"
require_relative "template_processors"

module RailsOpenapiGen
  module Parsers
    class ControllerParser
      attr_reader :route, :template_processor

      # Initializes controller parser with route information and template processor
      # @param route [Hash] Route hash containing controller and action info
      # @param template_processor [ResponseTemplateProcessor] Template processor for extracting template paths
      def initialize(route, template_processor: nil)
        @route = route
        @template_processor = template_processor || RailsOpenapiGen::Parsers::TemplateProcessors::JbuilderTemplateProcessor.new(route[:controller], route[:action])
      end

      # Parses controller to find action method and response template
      # @return [Hash] Controller info including paths and parameters
      def parse
        controller_path = find_controller_file
        return {} unless controller_path

        content = File.read(controller_path)
        ast = Parser::CurrentRuby.parse(content)
        
        action_node = find_action_method(ast)
        return {} unless action_node

        template_path = extract_template_path(action_node)
        parameters = extract_parameters_from_comments(content, action_node)
        
        {
          controller_path: controller_path,
          jbuilder_path: template_path, # Keep existing key name for backward compatibility
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

      # Extracts template path from action method using template processor
      # @param action_node [Parser::AST::Node] Action method node
      # @return [String, nil] Path to template or nil
      def extract_template_path(action_node)
        return nil unless action_node

        # Try to extract explicit template path from action
        template_path = template_processor.extract_template_path(action_node, route)
        
        # If no explicit template found, check for default template
        template_path ||= template_processor.find_default_template(route)
        
        template_path
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
          super(node)
        end
      end

    end
  end
end