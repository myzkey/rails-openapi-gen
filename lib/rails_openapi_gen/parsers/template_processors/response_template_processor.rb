# frozen_string_literal: true

module RailsOpenapiGen
  module Parsers
    module TemplateProcessors
      module ResponseTemplateProcessor
        def extract_template_path(action_node, route)
          raise NotImplementedError, "#{self.class} must implement #extract_template_path"
        end

        def find_default_template(route)
          raise NotImplementedError, "#{self.class} must implement #find_default_template"
        end
      end
    end
  end
end