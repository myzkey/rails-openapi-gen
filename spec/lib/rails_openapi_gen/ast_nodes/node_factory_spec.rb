require 'spec_helper'

RSpec.describe RailsOpenapiGen::AstNodes::NodeFactory do
  let(:comment_data) do
    RailsOpenapiGen::AstNodes::CommentData.new(
      type: 'string',
      description: 'Test description'
    )
  end

  describe '.create_property' do
    it 'creates a PropertyNode with given attributes' do
      node = described_class.create_property(
        property_name: 'name',
        comment_data: comment_data,
        is_conditional: true
      )

      expect(node).to be_a(RailsOpenapiGen::AstNodes::PropertyNode)
      expect(node.property_name).to eq('name')
      expect(node.comment_data).to eq(comment_data)
      expect(node.is_conditional).to be true
    end

    it 'creates PropertyNode with default values' do
      node = described_class.create_property(property_name: 'test')

      expect(node).to be_a(RailsOpenapiGen::AstNodes::PropertyNode)
      expect(node.property_name).to eq('test')
      expect(node.comment_data).to be_a(RailsOpenapiGen::AstNodes::CommentData)
      expect(node.is_conditional).to be false
    end

    it 'requires property_name' do
      expect do
        described_class.create_property
      end.to raise_error(ArgumentError)
    end
  end

  describe '.create_object' do
    it 'creates an ObjectNode with given attributes' do
      node = described_class.create_object(
        property_name: 'user',
        comment_data: comment_data,
        is_conditional: true
      )

      expect(node).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
      expect(node.property_name).to eq('user')
      expect(node.comment_data).to eq(comment_data)
      expect(node.is_conditional).to be true
    end

    # NOTE: create_object requires property_name parameter according to implementation
    it 'creates ObjectNode with required property_name' do
      node = described_class.create_object(property_name: 'test')

      expect(node).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
      expect(node.property_name).to eq('test')
      expect(node.comment_data).to be_a(RailsOpenapiGen::AstNodes::CommentData)
      expect(node.comment_data.type).to eq('object')
      expect(node.is_conditional).to be false
    end

    it 'accepts property_name as nil' do
      node = described_class.create_object(property_name: nil)

      expect(node).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
      expect(node.property_name).to be_nil
    end
  end

  describe '.create_array' do
    it 'creates an ArrayNode with given attributes' do
      node = described_class.create_array(
        property_name: 'items',
        comment_data: comment_data,
        is_conditional: true,
        is_root_array: true
      )

      expect(node).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
      expect(node.property_name).to eq('items')
      expect(node.comment_data).to eq(comment_data)
      expect(node.is_conditional).to be true
      expect(node.is_root_array).to be true
    end

    it 'creates ArrayNode with default values' do
      node = described_class.create_array

      expect(node).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
      expect(node.property_name).to be_nil
      expect(node.comment_data).to be_a(RailsOpenapiGen::AstNodes::CommentData)
      expect(node.comment_data.type).to eq('array')
      expect(node.is_conditional).to be false
      expect(node.is_root_array).to be false
    end

    it 'handles root array creation' do
      node = described_class.create_array(is_root_array: true)

      expect(node).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
      expect(node.is_root_array).to be true
      expect(node.property_name).to eq('items') # Default for root arrays
    end

    it 'handles non-root array creation' do
      node = described_class.create_array(
        property_name: 'tags',
        is_root_array: false
      )

      expect(node).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
      expect(node.property_name).to eq('tags')
      expect(node.is_root_array).to be false
    end
  end

  describe '.create_partial' do
    it 'creates a PartialNode with given attributes' do
      node = described_class.create_partial(
        property_name: 'user_partial',
        partial_path: 'api/users/user',
        local_variables: { user: 'current_user' },
        comment_data: comment_data,
        is_conditional: true
      )

      expect(node).to be_a(RailsOpenapiGen::AstNodes::PartialNode)
      expect(node.property_name).to eq('user_partial')
      expect(node.partial_path).to eq('api/users/user')
      expect(node.local_variables).to eq({ user: 'current_user' })
      expect(node.comment_data).to eq(comment_data)
      expect(node.is_conditional).to be true
    end

    it 'creates PartialNode with default values' do
      node = described_class.create_partial(
        partial_path: 'test/partial'
      )

      expect(node).to be_a(RailsOpenapiGen::AstNodes::PartialNode)
      expect(node.property_name).to be_nil
      expect(node.partial_path).to eq('test/partial')
      expect(node.local_variables).to eq({})
      expect(node.comment_data).to be_a(RailsOpenapiGen::AstNodes::CommentData)
      expect(node.is_conditional).to be false
    end

    it 'requires partial_path' do
      expect do
        described_class.create_partial
      end.to raise_error(ArgumentError)
    end
  end

  describe 'factory method integration' do
    it 'creates nodes that can be used together' do
      # Create a root object
      root = described_class.create_object(property_name: 'user')

      # Create properties
      id_prop = described_class.create_property(
        property_name: 'id',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'integer')
      )

      name_prop = described_class.create_property(
        property_name: 'name',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'string')
      )

      # Create nested object
      profile = described_class.create_object(property_name: 'profile')

      # Create array
      tags = described_class.create_array(property_name: 'tags')

      # Build structure
      root.add_property(id_prop)
      root.add_property(name_prop)
      root.add_property(profile)
      root.add_property(tags)

      expect(root.properties.size).to eq(4)
      expect(root.properties.map(&:property_name)).to contain_exactly('id', 'name', 'profile', 'tags')
      expect(id_prop.parent).to eq(root)
      expect(profile.parent).to eq(root)
      expect(tags.parent).to eq(root)
    end

    it 'creates nodes with proper types' do
      string_prop = described_class.create_property(
        property_name: 'name',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'string')
      )

      integer_prop = described_class.create_property(
        property_name: 'id',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'integer')
      )

      object_node = described_class.create_object(
        property_name: 'test_object',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'object')
      )

      array_node = described_class.create_array(
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'array')
      )

      expect(string_prop.openapi_type).to eq('string')
      expect(integer_prop.openapi_type).to eq('integer')
      expect(object_node.comment_data.type).to eq('object')
      expect(array_node.comment_data.type).to eq('array')
    end
  end

  describe 'conditional node creation' do
    it 'creates conditional properties correctly' do
      node = described_class.create_property(
        property_name: 'admin_notes',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'string',
          required: true
        ),
        is_conditional: true
      )

      expect(node.is_conditional).to be true
      expect(node.required?).to be false # Conditional overrides required
    end

    it 'creates conditional objects correctly' do
      node = described_class.create_object(
        property_name: 'profile',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'object',
          required: true
        ),
        is_conditional: true
      )

      expect(node.is_conditional).to be true
      expect(node.required?).to be false # Conditional overrides required
    end

    it 'creates conditional arrays correctly' do
      node = described_class.create_array(
        property_name: 'optional_items',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'array',
          required: true
        ),
        is_conditional: true
      )

      expect(node.is_conditional).to be true
      expect(node.required?).to be false # Conditional overrides required
    end
  end
end
