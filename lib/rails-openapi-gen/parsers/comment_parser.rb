# frozen_string_literal: true

require_relative 'comment_parsers/conditional_parser'
require_relative 'comment_parsers/operation_parser'
require_relative 'comment_parsers/param_parser'
require_relative 'comment_parsers/query_parser'
require_relative 'comment_parsers/body_parser'
require_relative 'comment_parsers/attribute_parser'

module RailsOpenapiGen
  module Parsers
    class CommentParser
      def initialize
        @parsers = [
          ConditionalParser.new,
          OperationParser.new,
          ParamParser.new,
          QueryParser.new,
          BodyParser.new,
          AttributeParser.new
        ]
      end

      def parse(comment_text)
        parser = find_parser(comment_text)
        return nil unless parser

        parser.parse(comment_text)
      end

      private

      def find_parser(comment_text)
        @parsers.find do |parser|
          comment_text.match?(parser.class::REGEX)
        end
      end
    end
  end
end
