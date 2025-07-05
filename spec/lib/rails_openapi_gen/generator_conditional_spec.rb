# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsOpenapiGen::Generator do
  describe 'conditional properties in schema generation' do
    let(:generator) { described_class.new }

    context 'with conditional properties' do
      let(:properties) do
        [
          {
            property: 'id',
            comment_data: { type: 'integer', required: 'true', description: 'User ID' }
          },
          {
            property: 'name',
            comment_data: { type: 'string', required: 'true', description: 'User name' }
          },
          {
            property: 'profile',
            comment_data: { type: 'object', required: 'true', description: 'User profile' },
            is_conditional: true,
            is_object: true,
            nested_properties: [
              {
                property: 'bio',
                comment_data: { type: 'string', description: 'Biography' },
                is_conditional: true
              },
              {
                property: 'verified',
                comment_data: { type: 'boolean', required: 'true', description: 'Verified status' },
                is_conditional: true
              }
            ]
          },
          {
            property: 'email',
            comment_data: { type: 'string', required: 'true', description: 'User email' }
          }
        ]
      end

      it 'excludes conditional properties from required array even if marked as required' do
        schema = generator.send(:build_schema, properties)

        expect(schema['type']).to eq('object')
        expect(schema['properties']).to include('id', 'name', 'profile', 'email')
        
        # Only non-conditional required properties should be in required array
        expect(schema['required']).to include('id', 'name', 'email')
        expect(schema['required']).not_to include('profile')
      end

      it 'excludes nested conditional properties from required array' do
        schema = generator.send(:build_schema, properties)
        
        profile_schema = schema['properties']['profile']
        expect(profile_schema['type']).to eq('object')
        expect(profile_schema['properties']).to include('bio', 'verified')
        
        # Nested conditional properties should not be in required array
        # When all nested properties are conditional, required field should not be present
        expect(profile_schema['required']).to be_nil
      end
    end

    context 'with array containing conditional properties' do
      let(:properties) do
        [
          {
            property: 'items',
            comment_data: { type: 'array' },
            is_array_root: true,
            array_item_properties: [
              {
                property: 'id',
                comment_data: { type: 'integer', required: 'true', description: 'Item ID' }
              },
              {
                property: 'optional_field',
                comment_data: { type: 'string', required: 'true', description: 'Optional field' },
                is_conditional: true
              }
            ]
          }
        ]
      end

      it 'excludes conditional array item properties from required array' do
        schema = generator.send(:build_array_schema, properties)

        expect(schema['type']).to eq('array')
        expect(schema['items']['type']).to eq('object')
        expect(schema['items']['properties']).to include('id', 'optional_field')
        
        # Only non-conditional required properties should be in required array
        expect(schema['items']['required']).to include('id')
        expect(schema['items']['required']).not_to include('optional_field')
      end
    end
  end
end