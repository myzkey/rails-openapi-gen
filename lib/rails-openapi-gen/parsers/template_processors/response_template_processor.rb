# frozen_string_literal: true

module RailsOpenapiGen::Parsers::TemplateProcessors
  module ResponseTemplateProcessor
    def extract_template_path(_action_node, _route)
      raise NotImplementedError, "#{self.class} must implement #extract_template_path"
    end

    def find_default_template(_route)
      raise NotImplementedError, "#{self.class} must implement #find_default_template"
    end
  end
end
