# frozen_string_literal: true

require "rails/railtie"

module RailsOpenapiGen
  class Railtie < Rails::Railtie
    rake_tasks do
      load File.expand_path("tasks/openapi.rake", __dir__)
    end
  end
end