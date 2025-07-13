# frozen_string_literal: true

module RailsOpenapiGen
  module Parsers
    module BaseAttributeParser
      private

      def clean_value(value)
        value = value.strip

        if value.start_with?('"') && value.end_with?('"')
          value[1..-2]
        else
          value
        end
      end

      def parse_enum(value)
        return value unless value.is_a?(String) && value.start_with?('[') && value.end_with?(']')

        inner = value[1..-2]

        inner.split(',').map do |item|
          item = item.strip
          if item.start_with?('"') && item.end_with?('"')
            item[1..-2]
          else
            item
          end
        end
      end

      def parse_key_value_pairs(content)
        content.scan(/(\w+):("[^"]*"|\[[^\]]*\]|\S+)/)
      end
    end
  end
end
