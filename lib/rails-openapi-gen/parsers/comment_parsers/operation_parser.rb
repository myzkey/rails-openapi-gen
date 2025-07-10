# frozen_string_literal: true

require_relative 'base_attribute_parser'

module RailsOpenapiGen
  module Parsers
    class OperationParser
      include BaseAttributeParser

      REGEX = /@openapi_operation\s+(.+)$/

      def parse(comment_text)
        match = comment_text.match(REGEX)
        return nil unless match

        openapi_content = match[1].strip
        { operation: parse_operation_attributes(openapi_content) }
      end

      private

      def parse_operation_attributes(content)
        attributes = {}
        
        parts = parse_key_value_pairs(content)
        
        parts.each do |key, value|
          cleaned_value = clean_value(value)
          
          case key
          when "summary"
            attributes[:summary] = cleaned_value
          when "description"
            attributes[:description] = cleaned_value
          when "operationId"
            attributes[:operationId] = cleaned_value
          when "tags"
            attributes[:tags] = parse_enum(cleaned_value)
          when "status", "statusCode", "status_code"
            attributes[:status] = cleaned_value
          else
            attributes[key.to_sym] = cleaned_value
          end
        end
        
        attributes
      end
    end
  end
end