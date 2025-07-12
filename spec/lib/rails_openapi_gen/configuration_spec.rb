# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsOpenapiGen::Configuration do
  let(:config) { described_class.new }

  describe "#initialize" do
    it "sets default values" do
      expect(config.openapi_version).to eq("3.0.0")
      expect(config.info[:title]).to eq("RailsApp")
      expect(config.info[:version]).to eq("1.0.0")
      expect(config.servers).to include(
        hash_including(url: "http://localhost:3000")
      )
      expect(config.output[:directory]).to eq("openapi")
      expect(config.output[:filename]).to eq("openapi.yaml")
      expect(config.output[:split_files]).to be true
    end
  end

  describe "#route_included?" do
    context "with default patterns" do
      it "includes all routes by default" do
        expect(config.route_included?("/users")).to be true
        expect(config.route_included?("/api/v1/users")).to be true
        expect(config.route_included?("/health")).to be true
      end
    end

    context "with custom patterns" do
      before do
        config.route_patterns = {
          include: [/^\/api\/v1\//],
          exclude: [/\/health/, /\/metrics/]
        }
      end

      it "includes only matching patterns" do
        expect(config.route_included?("/api/v1/users")).to be true
        expect(config.route_included?("/api/v2/users")).to be false
        expect(config.route_included?("/users")).to be false
      end

      it "excludes matching exclude patterns" do
        expect(config.route_included?("/api/v1/health")).to be false
        expect(config.route_included?("/api/v1/metrics")).to be false
        expect(config.route_included?("/api/v1/users")).to be true
      end
    end
  end

  describe "#output_directory" do
    it "returns relative path joined with Rails root" do
      config.update_output_config(directory: "docs/api")
      expect(config.output_directory).to end_with("/fixtures/docs/api")
    end

    it "returns absolute path as-is" do
      config.update_output_config(directory: "/tmp/api")
      expect(config.output_directory).to eq("/tmp/api")
    end
  end

  describe "#load_from_file" do
    let(:config_file_path) { File.join(Rails.root, "config", "test_openapi.rb") }

    before do
      # Create a temporary Ruby config file for testing
      FileUtils.mkdir_p(File.dirname(config_file_path))
      File.write(config_file_path, <<~RUBY)
        RailsOpenapiGen.configure do |config|
          config.openapi_version = "3.1.0"
          config.info[:title] = "Custom API"
          config.info[:version] = "2.0.0"
          config.info[:description] = "Custom description"
          config.servers = [
            { url: "https://api.example.com", description: "Production" }
          ]
          config.route_patterns = {
            include: [%r{^/api/v1/}],
            exclude: [%r{/health}]
          }
          config.output = {
            directory: "custom/path",
            filename: "custom.yaml",
            split_files: false
          }
        end
      RUBY
    end

    after do
      File.delete(config_file_path) if File.exist?(config_file_path)
    end

    it "loads configuration from Ruby file" do
      config.load_from_file(config_file_path)

      expect(config.openapi_version).to eq("3.1.0")
      expect(config.info[:title]).to eq("Custom API")
      expect(config.info[:version]).to eq("2.0.0")
      expect(config.info[:description]).to eq("Custom description")
      expect(config.servers).to include(
        hash_including(url: "https://api.example.com")
      )
      expect(config.output[:directory]).to eq("custom/path")
      expect(config.output[:filename]).to eq("custom.yaml")
      expect(config.output[:split_files]).to be false
    end

    it "loads route patterns" do
      config.load_from_file(config_file_path)

      expect(config.route_included?("/api/v1/users")).to be true
      expect(config.route_included?("/api/v2/users")).to be false
      expect(config.route_included?("/api/v1/health")).to be false
    end
  end

  describe "module-level configuration" do
    it "allows configuration via block" do
      RailsOpenapiGen.configure do |c|
        c.info[:title] = "Configured API"
        c.openapi_version = "3.1.0"
      end

      config = RailsOpenapiGen.configuration
      expect(config.info[:title]).to eq("Configured API")
      expect(config.openapi_version).to eq("3.1.0")
    end

    it "resets configuration" do
      RailsOpenapiGen.configure { |c| c.info[:title] = "Custom" }
      RailsOpenapiGen.reset_configuration!

      config = RailsOpenapiGen.configuration
      expect(config.info[:title]).to eq("RailsApp")
    end
  end
end