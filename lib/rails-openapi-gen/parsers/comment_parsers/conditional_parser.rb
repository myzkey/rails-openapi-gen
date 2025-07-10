# frozen_string_literal: true

module RailsOpenapiGen
  module Parsers
    class ConditionalParser
      REGEX = /@openapi\s+conditional:true\s*$/

      def parse(_comment_text)
        { conditional: true }
      end
    end
  end
end