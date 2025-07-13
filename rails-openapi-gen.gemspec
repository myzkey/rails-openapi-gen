# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = "rails-openapi-gen"
  spec.version = "0.0.2"
  spec.authors = ["myzkey"]
  spec.email = ["myzkey.dev@example.com"]

  spec.summary = "Rails comment-driven OpenAPI generator"
  spec.description = "Generates OpenAPI specs from Rails apps by parsing routes, controllers, and view templates with @openapi comment annotations"
  spec.homepage = "https://github.com/myzkey/rails-openapi-gen"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.glob("lib/**/*") + Dir.glob("*.md") + Dir.glob("*.gemspec")
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "parser", ">= 3.0.0"
  spec.add_dependency "rails", ">= 6.0"
  spec.add_dependency "yaml", "~> 0.2"

  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.metadata['rubygems_mfa_required'] = 'true'
end
