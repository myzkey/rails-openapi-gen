# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsOpenapiGen::Parsers::JbuilderParser do
  describe 'conditional rendering support' do
    let(:test_file) { 'spec/fixtures/conditional_test.json.jbuilder' }
    let(:parser) { described_class.new(test_file) }

    before do
      FileUtils.mkdir_p('spec/fixtures')
      File.write(test_file, jbuilder_content)
    end

    after do
      File.delete(test_file) if File.exist?(test_file)
    end

    context 'with conditional comment' do
      let(:jbuilder_content) do
        <<~JBUILDER
          # @openapi id:integer required:true description:"User ID"
          json.id @user.id

          # @openapi name:string required:true description:"User name"
          json.name @user.name

          # @openapi conditional:true
          if @user.profile.present?
            # @openapi type:object description:"User profile information"
            json.profile do
              # @openapi bio:string description:"User biography"
              json.bio @user.profile.bio
              
              # @openapi verified:boolean required:true description:"Whether verified"
              json.verified @user.profile.verified
            end
          end

          # @openapi email:string required:true description:"User email"
          json.email @user.email
        JBUILDER
      end

      it 'marks properties inside conditional as conditional' do
        result = parser.parse
        properties = result[:properties]

        # Non-conditional properties should not be marked as conditional
        id_prop = properties.find { |p| p[:property] == 'id' }
        expect(id_prop[:is_conditional]).to be_falsy

        name_prop = properties.find { |p| p[:property] == 'name' }
        expect(name_prop[:is_conditional]).to be_falsy

        email_prop = properties.find { |p| p[:property] == 'email' }
        expect(email_prop[:is_conditional]).to be_falsy

        # Conditional property should be marked as conditional
        profile_prop = properties.find { |p| p[:property] == 'profile' }
        expect(profile_prop[:is_conditional]).to be_truthy
        expect(profile_prop[:is_object]).to be_truthy

        # Nested properties inside conditional should also be marked as conditional
        bio_prop = profile_prop[:nested_properties].find { |p| p[:property] == 'bio' }
        expect(bio_prop[:is_conditional]).to be_truthy

        verified_prop = profile_prop[:nested_properties].find { |p| p[:property] == 'verified' }
        expect(verified_prop[:is_conditional]).to be_truthy
      end
    end

    context 'without conditional comment' do
      let(:jbuilder_content) do
        <<~JBUILDER
          # @openapi id:integer required:true description:"User ID"
          json.id @user.id

          if @user.profile.present?
            # @openapi type:object description:"User profile information"
            json.profile do
              # @openapi bio:string description:"User biography"
              json.bio @user.profile.bio
            end
          end
        JBUILDER
      end

      it 'does not mark properties as conditional without the comment' do
        result = parser.parse
        properties = result[:properties]

        profile_prop = properties.find { |p| p[:property] == 'profile' }
        expect(profile_prop[:is_conditional]).to be_falsy

        bio_prop = profile_prop[:nested_properties].find { |p| p[:property] == 'bio' }
        expect(bio_prop[:is_conditional]).to be_falsy
      end
    end
  end
end