# frozen_string_literal: true

require "pathname"

# Mock Rails for testing BEFORE requiring the main library
class MockRails
  def self.root
    Pathname.new(File.expand_path("../fixtures", __FILE__))
  end
  
  def self.application
    MockApplication.new
  end

  class Engine
    def self.isolate_namespace(module_name)
      # Mock method
    end

    def self.rake_tasks(&block)
      # Mock method
    end
  end
end

class MockApplication
  def self.class
    MockApp
  end
end

class MockApp
  def self.module_parent_name
    "TestApp"
  end
end

# Set up Rails constant for tests
Object.const_set(:Rails, MockRails) unless defined?(Rails)

# Pre-load parser gem to avoid loading issues in specs
begin
  require 'parser/current'
rescue LoadError => e
  puts "Warning: Could not load parser gem: #{e.message}"
end

# Now require the main library
require "rails-openapi-gen"

# Load support files
Dir[File.join(__dir__, 'support', '*.rb')].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = "spec/examples.txt"
  config.disable_monkey_patching!
  config.warnings = true

  if config.files_to_run.one?
    config.default_formatter = "doc"
  end

  config.profile_examples = 10
  config.order = :random
  Kernel.srand config.seed

  # Reset configuration before each test
  config.before(:each) do
    RailsOpenapiGen.reset_configuration!
  end
end