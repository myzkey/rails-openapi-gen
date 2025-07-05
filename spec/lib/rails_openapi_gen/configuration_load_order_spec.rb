# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsOpenapiGen::Configuration, "load order", :skip => "TODO: Implement configuration loading" do
  let(:config) { described_class.new }
  let(:rails_root) { Rails.root.to_s }

  before do
    # Clean up any existing config files
    [
      "#{rails_root}/config/openapi.rb",
      "#{rails_root}/config/initializers/openapi.rb"
    ].each do |file|
      File.delete(file) if File.exist?(file)
    end
  end

  after do
    # Clean up test files
    [
      "#{rails_root}/config/openapi.rb",
      "#{rails_root}/config/initializers/openapi.rb"
    ].each do |file|
      File.delete(file) if File.exist?(file)
    end
  end

  describe "config file precedence" do
    it "prefers config/openapi.rb over config/initializers/openapi.rb" do
      # Create both files
      FileUtils.mkdir_p("#{rails_root}/config")
      FileUtils.mkdir_p("#{rails_root}/config/initializers")
      
      File.write("#{rails_root}/config/openapi.rb", <<~RUBY)
        RailsOpenapiGen.configure do |config|
          config.info[:title] = "Ruby Config"
        end
      RUBY
      
      File.write("#{rails_root}/config/initializers/openapi.rb", <<~RUBY)
        RailsOpenapiGen.configure do |config|
          config.info[:title] = "Initializer Config"
        end
      RUBY

      config.load_from_file
      expect(config.info[:title]).to eq("Ruby Config")
    end

    it "falls back to config/initializers/openapi.rb when others don't exist" do
      FileUtils.mkdir_p("#{rails_root}/config/initializers")
      
      File.write("#{rails_root}/config/initializers/openapi.rb", <<~RUBY)
        RailsOpenapiGen.configure do |config|
          config.info[:title] = "Initializer Config"
        end
      RUBY

      config.load_from_file
      expect(config.info[:title]).to eq("Initializer Config")
    end
  end

  describe "Ruby configuration files" do
    it "loads Ruby configuration from config/openapi.rb" do
      FileUtils.mkdir_p("#{rails_root}/config")
      
      File.write("#{rails_root}/config/openapi.rb", <<~RUBY)
        RailsOpenapiGen.configure do |config|
          config.openapi_version = "3.1.0"
          config.info[:title] = "Ruby Configured API"
          config.info[:version] = "2.0.0"
          config.output[:split_files] = false
        end
      RUBY

      config.load_from_file
      
      expect(config.openapi_version).to eq("3.1.0")
      expect(config.info[:title]).to eq("Ruby Configured API")
      expect(config.info[:version]).to eq("2.0.0")
      expect(config.split_files?).to be false
    end
  end

  describe "explicit file path" do
    it "loads specific file when path is provided" do
      FileUtils.mkdir_p("#{rails_root}/custom")
      
      File.write("#{rails_root}/custom/my_config.rb", <<~RUBY)
        RailsOpenapiGen.configure do |config|
          config.info[:title] = "Custom Config"
        end
      RUBY

      config.load_from_file("#{rails_root}/custom/my_config.rb")
      expect(config.info[:title]).to eq("Custom Config")
    end
  end
end