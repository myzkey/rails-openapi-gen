# frozen_string_literal: true

module RailsOpenapiGen
  module Parsers
    module Jbuilder
      class PropertyCommentParser
      # Initializes property comment parser
      # @param comments [Array] Array of comment objects
      def initialize(comments)
        @comments = comments
        @comment_parser = CommentParser.new
      end

      # Finds property comment for a specific line
      # @param line_number [Integer] Line number to find comment for
      # @return [Hash, nil] Parsed comment data or nil
      def find_property_comment_for_line(line_number)
        @comments.reverse.find do |comment|
          comment_line = comment.location.line
          comment_line == line_number - 1 || comment_line == line_number
        end&.then do |comment|
          @comment_parser.parse(comment.text)
        end
      end
      end
    end
  end
end