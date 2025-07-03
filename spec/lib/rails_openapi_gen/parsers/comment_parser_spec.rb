# frozen_string_literal: true

require "spec_helper"

RSpec.describe RailsOpenapiGen::Parsers::CommentParser do
  let(:parser) { described_class.new }

  describe "#parse" do
    context "with field-level @openapi comments" do
      it "parses basic field comment" do
        comment = "# @openapi id:integer required:true description:\"User ID\""
        result = parser.parse(comment)

        expect(result).to eq({
          field_name: "id",
          type: "integer",
          required: "true",
          description: "User ID"
        })
      end

      it "parses field with enum values" do
        comment = "# @openapi status:string enum:[active,inactive,suspended] description:\"User status\""
        result = parser.parse(comment)

        expect(result).to eq({
          field_name: "status",
          type: "string",
          enum: ["active", "inactive", "suspended"],
          description: "User status"
        })
      end

      it "parses field with minimal attributes" do
        comment = "# @openapi name:string"
        result = parser.parse(comment)

        expect(result).to eq({
          field_name: "name",
          type: "string"
        })
      end
    end

    context "with operation-level @openapi_operation comments" do
      it "parses basic operation comment" do
        comment = "# @openapi_operation summary:\"List users\" tags:[Users,Public] description:\"Returns all users\""
        result = parser.parse(comment)

        expect(result).to eq({
          operation: {
            summary: "List users",
            tags: ["Users", "Public"],
            description: "Returns all users"
          }
        })
      end

      it "parses operation with custom operationId" do
        comment = "# @openapi_operation summary:\"Get user\" operationId:\"getUserById\" tags:[Users]"
        result = parser.parse(comment)

        expect(result).to eq({
          operation: {
            summary: "Get user",
            operationId: "getUserById",
            tags: ["Users"]
          }
        })
      end

      it "parses operation with responseDescription" do
        comment = "# @openapi_operation summary:\"Create user\" responseDescription:\"Created user object\""
        result = parser.parse(comment)

        expect(result).to eq({
          operation: {
            summary: "Create user",
            responseDescription: "Created user object"
          }
        })
      end
    end

    context "with invalid comments" do
      it "returns nil for non-openapi comments" do
        comment = "# Regular comment without @openapi"
        result = parser.parse(comment)

        expect(result).to be_nil
      end

      it "returns nil for empty comment" do
        comment = ""
        result = parser.parse(comment)

        expect(result).to be_nil
      end
    end

    context "with complex attribute values" do
      it "handles quoted strings with spaces" do
        comment = "# @openapi name:string description:\"Full name with spaces\""
        result = parser.parse(comment)

        expect(result[:description]).to eq("Full name with spaces")
      end

      it "handles array values with mixed types" do
        comment = "# @openapi priority:string enum:[high,medium,low]"
        result = parser.parse(comment)

        expect(result[:enum]).to eq(["high", "medium", "low"])
      end
    end

    context "with conditional comments" do
      it "parses conditional comment" do
        comment = "# @openapi conditional:true"
        result = parser.parse(comment)

        expect(result).to eq({
          conditional: true
        })
      end

      it "does not parse conditional with extra attributes" do
        comment = "# @openapi conditional:true extra:content"
        result = parser.parse(comment)

        expect(result).to eq({
          field_name: "conditional",
          type: "true",
          extra: "content"
        })
      end
    end
  end
end