require 'spec_helper'

RSpec.describe RailsOpenapiGen::AstNodes::PropertyNode do
  let(:comment_data) do
    RailsOpenapiGen::AstNodes::CommentData.new(
      type: 'string',
      description: 'User name',
      required: true
    )
  end

  describe '#initialize' do
    it 'initializes with basic attributes' do
      node = described_class.new(
        property_name: 'name',
        comment_data: comment_data,
        is_conditional: true
      )

      expect(node.property_name).to eq('name')
      expect(node.comment_data).to eq(comment_data)
      expect(node.is_conditional).to be true
    end

    it 'sets default values' do
      node = described_class.new(property_name: 'test')

      expect(node.property_name).to eq('test')
      expect(node.comment_data).to be_a(RailsOpenapiGen::AstNodes::CommentData)
      expect(node.is_conditional).to be false
    end

    it 'requires property_name' do
      expect do
        described_class.new
      end.to raise_error(ArgumentError, /property_name/)
    end
  end

  describe '#required?' do
    context 'when not conditional and comment_data.required? is true' do
      let(:node) do
        described_class.new(
          property_name: 'name',
          comment_data: RailsOpenapiGen::AstNodes::CommentData.new(required: true),
          is_conditional: false
        )
      end

      it 'returns true' do
        expect(node.required?).to be true
      end
    end

    context 'when conditional' do
      let(:node) do
        described_class.new(
          property_name: 'name',
          comment_data: RailsOpenapiGen::AstNodes::CommentData.new(required: true),
          is_conditional: true
        )
      end

      it 'returns false' do
        expect(node.required?).to be false
      end
    end

    context 'when comment_data.required? is false' do
      let(:node) do
        described_class.new(
          property_name: 'name',
          comment_data: RailsOpenapiGen::AstNodes::CommentData.new(required: false),
          is_conditional: false
        )
      end

      it 'returns false' do
        expect(node.required?).to be false
      end
    end
  end

  describe '#optional?' do
    let(:node) { described_class.new(property_name: 'test') }

    it 'returns opposite of required?' do
      allow(node).to receive(:required?).and_return(true)
      expect(node.optional?).to be false

      allow(node).to receive(:required?).and_return(false)
      expect(node.optional?).to be true
    end
  end

  describe '#openapi_type' do
    it 'returns type from comment_data' do
      node = described_class.new(
        property_name: 'id',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'integer')
      )

      expect(node.openapi_type).to eq('integer')
    end

    it 'returns string as default when no type in comment_data' do
      node = described_class.new(
        property_name: 'test',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new
      )

      expect(node.openapi_type).to eq('string')  # Default is 'string', not nil
    end
  end

  describe '#description' do
    it 'returns description from comment_data' do
      node = described_class.new(
        property_name: 'name',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(description: 'User name')
      )

      expect(node.description).to eq('User name')
    end

    it 'returns nil when no description' do
      node = described_class.new(
        property_name: 'test',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new
      )

      expect(node.description).to be_nil
    end
  end

  describe '#enum_values' do
    it 'returns enum from comment_data' do
      node = described_class.new(
        property_name: 'status',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(enum: %w[active inactive])
      )

      expect(node.enum_values).to eq(%w[active inactive])
    end

    it 'returns nil when no enum' do
      node = described_class.new(
        property_name: 'test',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new
      )

      expect(node.enum_values).to be_nil
    end
  end

  # NOTE: format and example are accessed through comment_data, not direct methods

  describe '#to_h' do
    let(:node) do
      described_class.new(
        property_name: 'status',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'string',
          description: 'User status',
          enum: %w[active inactive]
        ),
        is_conditional: true
      )
    end

    it 'returns hash representation' do
      hash = node.to_h

      expect(hash).to include(
        :property_name,
        :comment_data,
        :is_conditional,
        :required,
        :openapi_type,
        :description,
        :enum
      )

      expect(hash[:property_name]).to eq('status')
      expect(hash[:openapi_type]).to eq('string')
      expect(hash[:description]).to eq('User status')
      expect(hash[:enum]).to eq(%w[active inactive])
      expect(hash[:is_conditional]).to be true
    end

    it 'compacts nil values' do
      node = described_class.new(
        property_name: 'simple',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'string')
      )

      hash = node.to_h
      expect(hash.keys).to include(:property_name, :openapi_type)
    end
  end

  describe '#accept' do
    let(:node) { described_class.new(property_name: 'test') }
    let(:visitor) { double('visitor') }

    it 'calls visitor.visit_property with self' do
      expect(visitor).to receive(:visit_property).with(node)
      node.accept(visitor)
    end
  end

  describe 'type-specific scenarios' do
    it 'handles string properties' do
      node = described_class.new(
        property_name: 'name',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'string',
          description: 'User name'
        )
      )

      expect(node.openapi_type).to eq('string')
      expect(node.description).to eq('User name')
    end

    it 'handles integer properties' do
      node = described_class.new(
        property_name: 'id',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'integer',
          description: 'User ID'
        )
      )

      expect(node.openapi_type).to eq('integer')
      expect(node.description).to eq('User ID')
    end

    it 'handles boolean properties' do
      node = described_class.new(
        property_name: 'active',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'boolean',
          description: 'Whether user is active'
        )
      )

      expect(node.openapi_type).to eq('boolean')
      expect(node.description).to eq('Whether user is active')
    end

    it 'handles enum properties' do
      node = described_class.new(
        property_name: 'role',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'string',
          enum: %w[admin user moderator],
          description: 'User role'
        )
      )

      expect(node.openapi_type).to eq('string')
      expect(node.enum_values).to eq(%w[admin user moderator])
      expect(node.description).to eq('User role')
    end

    it 'handles date-time properties' do
      node = described_class.new(
        property_name: 'created_at',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'string',
          format: 'date-time',
          description: 'Creation timestamp'
        )
      )

      expect(node.openapi_type).to eq('string')
      expect(node.comment_data.format).to eq('date-time')
      expect(node.description).to eq('Creation timestamp')
    end
  end

  describe 'conditional property scenarios' do
    it 'handles conditional required properties' do
      node = described_class.new(
        property_name: 'admin_notes',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'string',
          required: true,
          description: 'Admin notes'
        ),
        is_conditional: true
      )

      # Even though comment_data says required: true, conditional properties are not required
      expect(node.required?).to be false
      expect(node.optional?).to be true
      expect(node.is_conditional).to be true
    end

    it 'handles conditional optional properties' do
      node = described_class.new(
        property_name: 'optional_field',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'string',
          required: false,
          description: 'Optional field'
        ),
        is_conditional: true
      )

      expect(node.required?).to be false
      expect(node.optional?).to be true
      expect(node.is_conditional).to be true
    end
  end
end
