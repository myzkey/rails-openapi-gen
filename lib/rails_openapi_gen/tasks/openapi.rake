# frozen_string_literal: true

namespace :openapi do
  desc "Generate OpenAPI specification from Rails application"
  task generate: :environment do
    require "rails_openapi_gen"
    RailsOpenapiGen.generate
  end

  desc "Check for missing @openapi comments and uncommitted changes"
  task check: :environment do
    require "rails_openapi_gen"
    RailsOpenapiGen.check
  end
end