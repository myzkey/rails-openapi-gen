# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsOpenapiGen::Generators::YamlGenerator do
  let(:mock_schemas) do
    {
      { path: "/users", method: "GET", controller: "users", action: "index" } => {
        schema: {
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
        parameters: {},
        operation: {}
      },
      { path: "/users/:id", method: "GET", controller: "users", action: "show" } => {
        schema: {
          "type" => "object",
          "properties" => {
            "id" => { "type" => "integer", "description" => "User ID" },
            "name" => { "type" => "string", "description" => "User name" },
            "email" => { "type" => "string", "description" => "User email" }
          },
          "required" => ["id", "name"]
        },
        parameters: {},
        operation: {}
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

  # Additional comprehensive test cases
  describe "parameter handling" do
    let(:schemas_with_params) do
      {
        { path: "/users/:id", method: "GET", controller: "users", action: "show" } => {
          schema: { "type" => "object", "properties" => { "id" => { "type" => "integer" } } },
          parameters: {
            path_parameters: [
              { name: "id", type: "integer", description: "User ID" }
            ],
            query_parameters: [
              { name: "include", type: "string", description: "Include relationships", required: "false" },
              { name: "format", type: "string", enum: ["json", "xml"], required: "true" }
            ]
          },
          operation: {}
        }
      }
    end

    let(:param_generator) { described_class.new(schemas_with_params) }

    it "generates path parameters correctly" do
      param_generator.generate

      paths_file = File.join(output_dir, "paths", "users.yaml")
      content = YAML.load_file(paths_file)
      
      parameters = content["/users/{id}"]["get"]["parameters"]
      path_param = parameters.find { |p| p["in"] == "path" }
      
      expect(path_param["name"]).to eq("id")
      expect(path_param["required"]).to be true
      expect(path_param["schema"]["type"]).to eq("integer")
      expect(path_param["description"]).to eq("User ID")
    end

    it "generates query parameters correctly" do
      param_generator.generate

      paths_file = File.join(output_dir, "paths", "users.yaml")
      content = YAML.load_file(paths_file)
      
      parameters = content["/users/{id}"]["get"]["parameters"]
      query_params = parameters.select { |p| p["in"] == "query" }
      
      expect(query_params.size).to eq(2)
      
      include_param = query_params.find { |p| p["name"] == "include" }
      expect(include_param["required"]).to be false
      expect(include_param["description"]).to eq("Include relationships")
      
      format_param = query_params.find { |p| p["name"] == "format" }
      expect(format_param["required"]).to be true
      expect(format_param["schema"]["enum"]).to eq(["json", "xml"])
    end
  end

  describe "request body handling" do
    let(:schemas_with_body) do
      {
        { path: "/users", method: "POST", controller: "users", action: "create" } => {
          schema: { "type" => "object", "properties" => { "id" => { "type" => "integer" } } },
          parameters: {
            body_parameters: [
              { name: "name", type: "string", description: "User name", required: "true" },
              { name: "email", type: "string", format: "email", description: "User email", required: "true" },
              { name: "age", type: "integer", minimum: 0, maximum: 150, required: "false" }
            ]
          },
          operation: {}
        }
      }
    end

    let(:body_generator) { described_class.new(schemas_with_body) }

    it "generates request body schema correctly" do
      body_generator.generate

      paths_file = File.join(output_dir, "paths", "users.yaml")
      content = YAML.load_file(paths_file)
      
      request_body = content["/users"]["post"]["requestBody"]
      expect(request_body["required"]).to be true
      
      schema = request_body["content"]["application/json"]["schema"]
      expect(schema["type"]).to eq("object")
      expect(schema["required"]).to contain_exactly("name", "email")
      
      properties = schema["properties"]
      expect(properties["name"]["type"]).to eq("string")
      expect(properties["email"]["format"]).to eq("email")
      expect(properties["age"]["minimum"]).to eq(0)
      expect(properties["age"]["maximum"]).to eq(150)
    end
  end

  describe "operation metadata handling" do
    let(:schemas_with_operation) do
      {
        { path: "/users", method: "GET", controller: "users", action: "index" } => {
          schema: { "type" => "array", "items" => { "type" => "object" } },
          parameters: {},
          operation: {
            summary: "List all users",
            description: "Retrieves a paginated list of all users in the system",
            operationId: "listUsers",
            tags: ["User Management"],
            status: "200"
          }
        }
      }
    end

    let(:operation_generator) { described_class.new(schemas_with_operation) }

    it "uses operation metadata when provided" do
      operation_generator.generate

      paths_file = File.join(output_dir, "paths", "users.yaml")
      content = YAML.load_file(paths_file)
      
      operation = content["/users"]["get"]
      expect(operation["summary"]).to eq("List all users")
      expect(operation["description"]).to eq("Retrieves a paginated list of all users in the system")
      expect(operation["operationId"]).to eq("listUsers")
      expect(operation["tags"]).to eq(["User Management"])
      expect(operation["responses"]["200"]).not_to be_nil
    end
  end

  describe "schema validation and skipping" do
    let(:invalid_schemas) do
      {
        # Valid schema
        { path: "/users", method: "GET", controller: "users", action: "index" } => {
          schema: { "type" => "object", "properties" => { "id" => { "type" => "integer" } } },
          parameters: {},
          operation: {}
        },
        # Invalid object schema (no properties)
        { path: "/empty", method: "GET", controller: "empty", action: "index" } => {
          schema: { "type" => "object", "properties" => {} },
          parameters: {},
          operation: {}
        },
        # Invalid array schema (no items)
        { path: "/broken", method: "GET", controller: "broken", action: "index" } => {
          schema: { "type" => "array" },
          parameters: {},
          operation: {}
        }
      }
    end

    let(:invalid_generator) { described_class.new(invalid_schemas) }

    it "skips invalid schemas and only generates valid ones" do
      invalid_generator.generate

      paths_file = File.join(output_dir, "paths", "users.yaml")
      content = YAML.load_file(paths_file)
      
      # Should only contain the valid schema
      expect(content.keys).to eq(["/users"])
      expect(content).not_to have_key("/empty")
      expect(content).not_to have_key("/broken")
    end
  end

  describe "utility methods" do
    describe "#extract_resource_name" do
      it "extracts resource names correctly" do
        expect(generator.send(:extract_resource_name, "/users")).to eq("users")
        expect(generator.send(:extract_resource_name, "/users/{id}")).to eq("users")
        expect(generator.send(:extract_resource_name, "/api/v1/posts")).to eq("api")
        expect(generator.send(:extract_resource_name, "")).to eq("root")
        expect(generator.send(:extract_resource_name, "/")).to eq("root")
      end
    end

    describe "#humanize" do
      it "converts strings to human readable format" do
        expect(generator.send(:humanize, "user_posts")).to eq("User Posts")
        expect(generator.send(:humanize, "api_v1")).to eq("Api V1")
        expect(generator.send(:humanize, "index")).to eq("Index")
      end
    end

    describe "#singularize" do
      it "singularizes strings" do
        expect(generator.send(:singularize, "users")).to eq("user")
        expect(generator.send(:singularize, "posts")).to eq("post")
        expect(generator.send(:singularize, "user")).to eq("user")
      end
    end

    describe "#deep_stringify_keys" do
      it "recursively converts symbol keys to strings" do
        input = {
          :title => "Test",
          :nested => {
            :key => "value",
            :array => [{ :item => "test" }]
          }
        }
        
        result = generator.send(:deep_stringify_keys, input)
        
        expect(result["title"]).to eq("Test")
        expect(result["nested"]["key"]).to eq("value")
        expect(result["nested"]["array"][0]["item"]).to eq("test")
      end
    end
  end

  describe "edge cases" do
    context "with empty schemas hash" do
      let(:empty_generator) { described_class.new({}) }

      it "generates empty but valid OpenAPI files" do
        empty_generator.generate

        main_file = File.join(output_dir, "test_api.yaml")
        content = YAML.load_file(main_file)

        expect(content["openapi"]).not_to be_nil
        expect(content["info"]).not_to be_nil
        expect(content["paths"]).to eq({})
      end
    end
  end
end