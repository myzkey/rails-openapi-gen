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

  desc "Import OpenAPI specification and add comments to Jbuilder templates"
  task import: :environment do |_task, args|
    require "rails_openapi_gen"
    openapi_file = args.extras.first
    RailsOpenapiGen.import(openapi_file)
  end
end