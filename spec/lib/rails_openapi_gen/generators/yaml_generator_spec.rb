# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsOpenapiGen::Generators::YamlGenerator do
  let(:mock_schemas) do
    {
      { path: "/users", method: "GET", controller: "users", action: "index" } => {
        "type" => "object",
        "properties" => {
          "users" => {
            "type" => "array",
            "items" => {
              "type" => "object",
              "properties" => {
                "id" => { "type" => "integer", "description" => "User ID" },
                "name" => { "type" => "string", "description" => "User name" }
              },
              "required" => ["id", "name"]
            }
          }
        }
      },
      { path: "/users/:id", method: "GET", controller: "users", action: "show" } => {
        "type" => "object",
        "properties" => {
          "id" => { "type" => "integer", "description" => "User ID" },
          "name" => { "type" => "string", "description" => "User name" },
          "email" => { "type" => "string", "description" => "User email" }
        },
        "required" => ["id", "name"]
      }
    }
  end

  let(:generator) { described_class.new(mock_schemas) }
  let(:output_dir) { File.join(Rails.root, "tmp", "test_output") }

  before do
    RailsOpenapiGen.configure do |config|
      config.output = {
        directory: "tmp/test_output",
        filename: "test_api.yaml",
        split_files: true
      }
    end
    
    FileUtils.rm_rf(output_dir) if Dir.exist?(output_dir)
  end

  after do
    FileUtils.rm_rf(output_dir) if Dir.exist?(output_dir)
  end

  describe "#generate" do
    context "with split files enabled" do
      it "creates main OpenAPI file and paths directory" do
        generator.generate

        expect(File.exist?(File.join(output_dir, "test_api.yaml"))).to be true
        expect(Dir.exist?(File.join(output_dir, "paths"))).to be true
      end

      it "generates paths files grouped by resource" do
        generator.generate

        paths_file = File.join(output_dir, "paths", "users.yaml")
        expect(File.exist?(paths_file)).to be true

        content = YAML.load_file(paths_file)
        expect(content).to have_key("/users")
        expect(content).to have_key("/users/{id}")
      end

      it "generates main OpenAPI file with correct structure" do
        generator.generate

        main_file = File.join(output_dir, "test_api.yaml")
        content = YAML.load_file(main_file)

        expect(content["openapi"]).to eq("3.0.0")
        expect(content["info"]["title"]).to eq("RailsApp")
        expect(content["paths"]).to have_key("/users")
        expect(content["paths"]).to have_key("/users/{id}")
      end
    end

    context "with split files disabled" do
      before do
        RailsOpenapiGen.configure do |config|
          config.output = {
            directory: "tmp/test_output",
            filename: "single_api.yaml",
            split_files: false
          }
        end
      end

      it "creates only main OpenAPI file" do
        generator.generate

        expect(File.exist?(File.join(output_dir, "single_api.yaml"))).to be true
        expect(Dir.exist?(File.join(output_dir, "paths"))).to be false
      end

      it "includes all paths in main file" do
        generator.generate

        main_file = File.join(output_dir, "single_api.yaml")
        content = YAML.load_file(main_file)

        expect(content["paths"]).to have_key("/users")
        expect(content["paths"]).to have_key("/users/{id}")
      end
    end
  end

  describe "#normalize_path" do
    it "converts Rails parameter format to OpenAPI format" do
      result = generator.send(:normalize_path, "/users/:id/posts/:post_id")
      expect(result).to eq("/users/{id}/posts/{post_id}")
    end
  end

  describe "#build_operation" do
    let(:route) { { path: "/users", method: "GET", controller: "users", action: "index" } }
    let(:schema) { mock_schemas[route] }

    it "builds operation with inline schema" do
      operation = generator.send(:build_operation, route, schema)

      expect(operation["summary"]).to_not be_empty
      expect(operation["operationId"]).to eq("users_index")
      expect(operation["responses"]["200"]["content"]["application/json"]["schema"]).to eq(schema)
    end

    it "includes tags based on controller" do
      operation = generator.send(:build_operation, route, schema)
      expect(operation["tags"]).to include("Users")
    end
  end
end