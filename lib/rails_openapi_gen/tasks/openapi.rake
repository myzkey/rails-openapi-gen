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
  task :import, [:openapi_file] => :environment do |_task, args|
    require "rails_openapi_gen"
    
    openapi_file = args[:openapi_file]
    
    if openapi_file.nil? || openapi_file.empty?
      puts "Usage: bin/rails openapi:import[PATH_TO_OPENAPI_FILE]"
      puts "Example: bin/rails openapi:import[docs/api/openapi.yaml]"
      exit 1
    end
    
    RailsOpenapiGen.import(openapi_file)
  end
end