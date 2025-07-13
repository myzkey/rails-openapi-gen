# frozen_string_literal: true

require_relative '../comment_parser'

module RailsOpenapiGen::Parsers::Jbuilder
  class OperationCommentParser
    # Initializes operation comment parser
    # @param comments [Array] Array of comment objects
    def initialize(comments)
      @comments = comments
      @comment_parser = RailsOpenapiGen::Parsers::CommentParser.new
    end

    # Parses operation comments to extract operation information
    # @return [Hash, nil] Operation information or nil if not found
    def parse_operation_info
      @comments.each do |comment|
        parsed = @comment_parser.parse(comment.text)
        if parsed&.dig(:operation)
          return parsed[:operation]
        end
      end
      nil
    end
  end
end
