require 'spec_helper'

RSpec.describe RailsOpenapiGen::AstNodes::ObjectNode do
  let(:comment_data) do
    RailsOpenapiGen::AstNodes::CommentData.new(
      type: 'object',
      description: 'Test object'
    )
  end

  describe '#initialize' do
    it 'initializes with basic attributes' do
      node = described_class.new(
        property_name: 'user',
        comment_data: comment_data,
        is_conditional: true
      )

      expect(node.property_name).to eq('user')
      expect(node.comment_data).to eq(comment_data)
      expect(node.is_conditional).to be true
    end

    it 'sets default values' do
      node = described_class.new(property_name: 'test')

      expect(node.property_name).to eq('test')
      expect(node.comment_data).to be_a(RailsOpenapiGen::AstNodes::CommentData)
      expect(node.comment_data.type).to eq('object')
      expect(node.is_conditional).to be false
    end
  end

  describe '#add_property' do
    let(:node) { described_class.new(property_name: 'user') }
    let(:property) do
      RailsOpenapiGen::AstNodes::PropertyNode.new(
        property_name: 'id',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'integer')
      )
    end

    it 'adds a property to the object' do
      node.add_property(property)
      expect(node.properties).to include(property)
    end

    it 'sets the parent of the property' do
      node.add_property(property)
      expect(property.parent).to eq(node)
    end

    it 'returns the added property' do
      result = node.add_property(property)
      expect(result).to eq(property)
    end
  end

  describe '#properties' do
    let(:node) { described_class.new(property_name: 'test') }

    it 'returns children as properties' do
      expect(node.properties).to eq(node.children)
    end
  end

  describe '#required?' do
    context 'when not conditional and comment_data.required? is true' do
      let(:node) do
        described_class.new(
          property_name: 'test',
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
          property_name: 'test',
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
          property_name: 'test',
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

  describe '#description' do
    it 'returns description from comment_data' do
      node = described_class.new(
        property_name: 'test',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(description: 'User object')
      )

      expect(node.description).to eq('User object')
    end

    it 'returns nil when no description' do
      node = described_class.new(
        property_name: 'test',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new
      )

      expect(node.description).to be_nil
    end
  end

  describe '#to_h' do
    let(:node) do
      described_class.new(
        property_name: 'profile',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'object',
          description: 'User profile'
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
        :properties
      )

      expect(hash[:property_name]).to eq('profile')
      expect(hash[:openapi_type]).to eq('object')
      expect(hash[:description]).to eq('User profile')
      expect(hash[:is_conditional]).to be true
    end

    it 'includes properties in hash' do
      property = RailsOpenapiGen::AstNodes::PropertyNode.new(
        property_name: 'name',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'string')
      )
      node.add_property(property)

      hash = node.to_h
      expect(hash[:properties].size).to eq(1)
    end
  end

  describe '#accept' do
    let(:node) { described_class.new(property_name: 'test') }
    let(:visitor) { double('visitor') }

    it 'calls visitor.visit_object with self' do
      expect(visitor).to receive(:visit_object).with(node)
      node.accept(visitor)
    end
  end

  describe 'complex scenarios' do
    it 'handles nested objects' do
      root = described_class.new(property_name: 'user')
      profile = described_class.new(property_name: 'profile')
      name_prop = RailsOpenapiGen::AstNodes::PropertyNode.new(
        property_name: 'name',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'string')
      )

      root.add_property(profile)
      profile.add_property(name_prop)

      expect(root.properties).to include(profile)
      expect(profile.properties).to include(name_prop)
      expect(name_prop.parent).to eq(profile)
      expect(profile.parent).to eq(root)
    end

    it 'handles multiple properties' do
      node = described_class.new(property_name: 'user')
      
      id_prop = RailsOpenapiGen::AstNodes::PropertyNode.new(
        property_name: 'id',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'integer')
      )
      
      name_prop = RailsOpenapiGen::AstNodes::PropertyNode.new(
        property_name: 'name',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'string')
      )

      node.add_property(id_prop)
      node.add_property(name_prop)

      expect(node.properties.size).to eq(2)
      expect(node.properties.map(&:property_name)).to contain_exactly('id', 'name')
    end

    it 'preserves property order' do
      node = described_class.new(property_name: 'user')
      
      props = %w[id name email created_at].map do |name|
        RailsOpenapiGen::AstNodes::PropertyNode.new(
          property_name: name,
          comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'string')
        )
      end

      props.each { |prop| node.add_property(prop) }

      expect(node.properties.map(&:property_name)).to eq(%w[id name email created_at])
    end
  end
end