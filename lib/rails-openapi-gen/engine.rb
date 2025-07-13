# frozen_string_literal: true

module RailsOpenapiGen
  class Engine < ::Rails::Engine
    isolate_namespace RailsOpenapiGen

    rake_tasks do
      load File.expand_path("tasks/openapi.rake", __dir__)
    end
  end
end
