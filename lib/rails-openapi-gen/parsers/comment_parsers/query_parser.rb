# frozen_string_literal: true

require_relative 'base_attribute_parser'

module RailsOpenapiGen
  module Parsers
    class QueryParser
      include BaseAttributeParser

      REGEX = /@openapi_query\s+(.+)$/

      def parse(comment_text)
        match = comment_text.match(REGEX)
        return nil unless match

        openapi_content = match[1].strip
        { query_parameter: parse_parameter_attributes(openapi_content) }
      end

      private

      def parse_parameter_attributes(content)
        attributes = {}
        
        parts = parse_key_value_pairs(content)
        
        # First part should be parameter_name:type
        if parts.any?
          first_key, first_value = parts.first
          attributes[:name] = first_key
          attributes[:type] = clean_value(first_value)
        end
        
        # Remaining parts are attributes
        parts[1..-1]&.each do |key, value|
          cleaned_value = clean_value(value)
          
          case key
          when "required"
            attributes[:required] = cleaned_value
          when "description"
            attributes[:description] = cleaned_value
          when "enum"
            attributes[:enum] = parse_enum(cleaned_value)
          when "format"
            attributes[:format] = cleaned_value
          when "minimum", "min"
            attributes[:minimum] = cleaned_value.to_i
          when "maximum", "max"
            attributes[:maximum] = cleaned_value.to_i
          when "example"
            attributes[:example] = cleaned_value
          else
            attributes[key.to_sym] = cleaned_value
          end
        end
        
        attributes
      end
    end
  end
end