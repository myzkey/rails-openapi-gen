# frozen_string_literal: true

module RailsOpenapiGen
  module Parsers
    class CommentParser
      OPENAPI_COMMENT_REGEX = /@openapi\s+(.+)$/
      OPENAPI_OPERATION_REGEX = /@openapi_operation\s+(.+)$/
      OPENAPI_PARAM_REGEX = /@openapi_param\s+(.+)$/
      OPENAPI_QUERY_REGEX = /@openapi_query\s+(.+)$/
      OPENAPI_BODY_REGEX = /@openapi_body\s+(.+)$/
      OPENAPI_CONDITIONAL_REGEX = /@openapi\s+conditional:true\s*$/

      def parse(comment_text)
        if comment_text.match?(OPENAPI_CONDITIONAL_REGEX)
          return { conditional: true }
        elsif match = comment_text.match(OPENAPI_OPERATION_REGEX)
          openapi_content = match[1].strip
          return { operation: parse_operation_attributes(openapi_content) }
        elsif match = comment_text.match(OPENAPI_PARAM_REGEX)
          openapi_content = match[1].strip
          return { parameter: parse_parameter_attributes(openapi_content) }
        elsif match = comment_text.match(OPENAPI_QUERY_REGEX)
          openapi_content = match[1].strip
          return { query_parameter: parse_parameter_attributes(openapi_content) }
        elsif match = comment_text.match(OPENAPI_BODY_REGEX)
          openapi_content = match[1].strip
          return { body_parameter: parse_parameter_attributes(openapi_content) }
        elsif match = comment_text.match(OPENAPI_COMMENT_REGEX)
          openapi_content = match[1].strip
          return parse_attributes(openapi_content)
        end
        
        nil
      end

      private

      def parse_attributes(content)
        attributes = {}
        
        parts = content.scan(/(\w+):("[^"]*"|\[[^\]]*\]|\S+)/)
        
        # First part should be field_name:type
        if parts.any?
          first_key, first_value = parts.first
          attributes[:field_name] = first_key
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
          else
            attributes[key.to_sym] = cleaned_value
          end
        end
        
        attributes
      end

      def parse_operation_attributes(content)
        attributes = {}
        
        parts = content.scan(/(\w+):("[^"]*"|\[[^\]]*\]|\S+)/)
        
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

      def clean_value(value)
        value = value.strip
        
        if value.start_with?('"') && value.end_with?('"')
          value[1..-2]
        elsif value.start_with?('[') && value.end_with?(']')
          value
        else
          value
        end
      end

      def parse_enum(value)
        return value unless value.is_a?(String) && value.start_with?('[') && value.end_with?(']')
        
        inner = value[1..-2]
        
        items = inner.split(',').map do |item|
          item = item.strip
          if item.start_with?('"') && item.end_with?('"')
            item[1..-2]
          else
            item
          end
        end
        
        items
      end

      def parse_parameter_attributes(content)
        attributes = {}
        
        parts = content.scan(/(\w+):("[^"]*"|\[[^\]]*\]|\S+)/)
        
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