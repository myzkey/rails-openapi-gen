# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsOpenapiGen do
  describe ".configuration" do
    it "returns a Configuration instance" do
      expect(described_class.configuration).to be_a(RailsOpenapiGen::Configuration)
    end

    it "returns the same instance on multiple calls" do
      config1 = described_class.configuration
      config2 = described_class.configuration
      expect(config1).to be(config2)
    end
  end

  describe ".configure" do
    it "yields the configuration instance" do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class.configuration)
    end

    it "allows configuration changes" do
      described_class.configure do |config|
        config.info[:title] = "Custom Title"
        config.openapi_version = "3.1.0"
      end

      config = described_class.configuration
      expect(config.info[:title]).to eq("Custom Title")
      expect(config.openapi_version).to eq("3.1.0")
    end
  end

  describe ".reset_configuration!" do
    it "creates a new configuration instance" do
      old_config = described_class.configuration
      old_config.info[:title] = "Modified"

      described_class.reset_configuration!
      new_config = described_class.configuration

      expect(new_config).not_to be(old_config)
      expect(new_config.info[:title]).to eq("RailsApp")
    end
  end

  describe RailsOpenapiGen::Generator do
    let(:generator) { described_class.new }

    describe "#build_schema" do
      let(:mock_ast) do
        [
          {
            property: "id",
            comment_data: {
              field_name: "id",
              type: "integer",
              required: "true",
              description: "User ID"
            }
          },
          {
            property: "name",
            comment_data: {
              field_name: "name",
              type: "string",
              required: "true",
              description: "User name"
            }
          },
          {
            property: "status",
            comment_data: {
              field_name: "status",
              type: "string",
              enum: ["active", "inactive"],
              description: "User status"
            }
          },
          {
            property: "missing_comment_field",
            comment_data: nil
          }
        ]
      end

      it "builds OpenAPI schema from AST data" do
        schema = generator.send(:build_schema, mock_ast)

        expect(schema["type"]).to eq("object")
        expect(schema["properties"]).to have_key("id")
        expect(schema["properties"]).to have_key("name")
        expect(schema["properties"]).to have_key("status")
        expect(schema["properties"]).to have_key("missing_comment_field")
      end

      it "sets correct property types" do
        schema = generator.send(:build_schema, mock_ast)

        expect(schema["properties"]["id"]["type"]).to eq("integer")
        expect(schema["properties"]["name"]["type"]).to eq("string")
        expect(schema["properties"]["status"]["type"]).to eq("string")
      end

      it "includes required fields" do
        schema = generator.send(:build_schema, mock_ast)

        expect(schema["required"]).to include("id")
        expect(schema["required"]).to include("name")
        expect(schema["required"]).not_to include("status")
      end

      it "includes enum values" do
        schema = generator.send(:build_schema, mock_ast)

        expect(schema["properties"]["status"]["enum"]).to eq(["active", "inactive"])
      end

      it "includes descriptions" do
        schema = generator.send(:build_schema, mock_ast)

        expect(schema["properties"]["id"]["description"]).to eq("User ID")
        expect(schema["properties"]["name"]["description"]).to eq("User name")
        expect(schema["properties"]["status"]["description"]).to eq("User status")
      end

      it "handles missing comments" do
        schema = generator.send(:build_schema, mock_ast)

        missing_field = schema["properties"]["missing_comment_field"]
        expect(missing_field["type"]).to eq("string")
        expect(missing_field["description"]).to include("TODO: MISSING COMMENT")
      end
    end
  end

  describe RailsOpenapiGen::Checker do
    let(:checker) { described_class.new }

    describe "#run" do
      before do
        allow(checker).to receive(:system)
        allow(checker).to receive(:`).and_return("")
        allow(checker).to receive(:puts)
      end

      it "runs openapi:generate command" do
        expect(checker).to receive(:system).with("bin/rails openapi:generate")
        checker.run rescue nil
      end

      context "when no missing comments" do
        before do
          allow(checker).to receive(:`).with("grep -r \"TODO: MISSING COMMENT\" openapi/").and_return("")
          allow(checker).to receive(:`).with("git diff --name-only openapi/").and_return("")
        end

        it "prints success message" do
          expect(checker).to receive(:puts).with("✅ OpenAPI spec is up to date!")
          checker.run
        end
      end

      context "when missing comments exist" do
        before do
          allow(checker).to receive(:`).with("grep -r \"TODO: MISSING COMMENT\" openapi/").and_return("some missing comments")
          allow(checker).to receive(:exit)
        end

        it "prints error message and exits" do
          expect(checker).to receive(:puts).with("❌ Missing @openapi comments found!")
          expect(checker).to receive(:exit).with(1)
          checker.run
        end
      end

      context "when uncommitted changes exist" do
        before do
          allow(checker).to receive(:`).with("grep -r \"TODO: MISSING COMMENT\" openapi/").and_return("")
          allow(checker).to receive(:`).with("git diff --name-only openapi/").and_return("openapi/openapi.yaml")
          allow(checker).to receive(:exit)
        end

        it "prints error message and exits" do
          expect(checker).to receive(:puts).with("❌ OpenAPI spec has uncommitted changes!")
          expect(checker).to receive(:exit).with(1)
          checker.run
        end
      end
    end
  end
end