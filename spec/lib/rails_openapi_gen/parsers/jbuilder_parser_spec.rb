# frozen_string_literal: true

require "spec_helper"
require "rails-openapi-gen/parsers/jbuilder/jbuilder_parser"
require "tmpdir"
require "fileutils"

RSpec.describe RailsOpenapiGen::Parsers::Jbuilder::JbuilderParser do
  let(:temp_dir) { Dir.mktmpdir }
  let(:main_template) { File.join(temp_dir, "show.json.jbuilder") }
  let(:partial_template) { File.join(temp_dir, "_user.json.jbuilder") }
  
  after do
    FileUtils.remove_entry(temp_dir)
  end

  describe "#parse" do
    context "with top-level partials" do
      it "includes properties from partials" do
        # Create the main template with top-level partial
        File.write(main_template, <<~JBUILDER)
          # @openapi_operation summary:"show" tags:[Users]
          json.partial! '_user', user: @user
        JBUILDER
        
        # Create the partial template
        File.write(partial_template, <<~JBUILDER)
          # @openapi name:string description:"User name"
          json.name user.name
          # @openapi email:string description:"User email"
          json.email user.email
        JBUILDER
        
        parser = described_class.new(main_template)
        result = parser.parse
        
        # Check that partial properties are included
        expect(result[:properties]).not_to be_empty
        expect(result[:properties].map { |p| p.property_name }).to include("name", "email")
      end
    end

    context "with nested objects containing partials" do
      it "includes properties from partials in nested objects" do
        # Create the main template with nested object containing partial
        File.write(main_template, <<~JBUILDER)
          # @openapi_operation summary:"show" tags:[Users]
          # @openapi user:object
          json.user do
            # @openapi id:integer
            json.id @user.id
            # @openapi professional:object
            json.professional do
              json.partial! '_user', user: @user
            end
          end
        JBUILDER
        
        # Create the partial template
        File.write(partial_template, <<~JBUILDER)
          # @openapi name:string description:"User name"
          json.name user.name
          # @openapi email:string description:"User email"
          json.email user.email
        JBUILDER
        
        parser = described_class.new(main_template)
        result = parser.parse
        
        # Find the user object property first, then the professional property inside it
        user_prop = result[:properties].find { |p| p.property_name == "user" }
        expect(user_prop).not_to be_nil
        
        professional_prop = user_prop.properties.find { |p| p.property_name == "professional" }
        expect(professional_prop).not_to be_nil
        expect(professional_prop).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
        expect(professional_prop.properties).not_to be_nil
        
        # Check that the nested properties include the partial's properties
        nested_properties = professional_prop.properties
        expect(nested_properties.map { |p| p.property_name }).to include("name", "email")
        
        # Verify the properties have the correct comment data
        name_prop = nested_properties.find { |p| p.property_name == "name" }
        expect(name_prop.comment_data.description).to eq("User name")
        
        email_prop = nested_properties.find { |p| p.property_name == "email" }
        expect(email_prop.comment_data.description).to eq("User email")
      end
    end
  end
end