require 'spec_helper'

RSpec.describe RailsOpenapiGen::AstNodes::ArrayNode do
  describe '#initialize' do
    context 'with root array' do
      let(:node) { described_class.new(is_root_array: true) }

      it 'sets property_name to items for root arrays' do
        expect(node.property_name).to eq('items')
      end

      it 'marks as root array' do
        expect(node.is_root_array).to be true
        expect(node.root_array?).to be true
      end
    end

    context 'with nested array' do
      let(:node) { described_class.new(property_name: 'tags', is_root_array: false) }

      it 'uses provided property name' do
        expect(node.property_name).to eq('tags')
      end

      it 'is not a root array' do
        expect(node.is_root_array).to be false
        expect(node.root_array?).to be false
      end
    end

    context 'with comment data' do
      let(:comment_data) do
        RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'array',
          description: 'List of items',
          items: { type: 'string' }
        )
      end
      let(:node) { described_class.new(comment_data: comment_data) }

      it 'stores comment data' do
        expect(node.comment_data).to eq(comment_data)
        expect(node.description).to eq('List of items')
      end
    end
  end

  describe '#add_item' do
    let(:node) { described_class.new(property_name: 'items') }
    let(:item) { RailsOpenapiGen::AstNodes::ObjectNode.new(property_name: 'item') }

    it 'adds item to children' do
      node.add_item(item)
      expect(node.items).to include(item)
      expect(node.items.length).to eq(1)
    end

    it 'sets parent relationship' do
      node.add_item(item)
      expect(item.parent).to eq(node)
    end

    it 'returns the added item' do
      result = node.add_item(item)
      expect(result).to eq(item)
    end
  end

  describe '#items' do
    let(:node) { described_class.new }
    let(:item1) { RailsOpenapiGen::AstNodes::ObjectNode.new(property_name: 'item1') }
    let(:item2) { RailsOpenapiGen::AstNodes::ObjectNode.new(property_name: 'item2') }

    before do
      node.add_item(item1)
      node.add_item(item2)
    end

    it 'returns all added items' do
      expect(node.items).to match_array([item1, item2])
    end
  end

  describe '#required?' do
    context 'when required and not conditional' do
      let(:comment_data) { RailsOpenapiGen::AstNodes::CommentData.new(required: true) }
      let(:node) { described_class.new(comment_data: comment_data, is_conditional: false) }

      it 'returns true' do
        expect(node.required?).to be true
      end
    end

    context 'when required but conditional' do
      let(:comment_data) { RailsOpenapiGen::AstNodes::CommentData.new(required: true) }
      let(:node) { described_class.new(comment_data: comment_data, is_conditional: true) }

      it 'returns false' do
        expect(node.required?).to be false
      end
    end

    context 'when not required' do
      let(:comment_data) { RailsOpenapiGen::AstNodes::CommentData.new(required: false) }
      let(:node) { described_class.new(comment_data: comment_data) }

      it 'returns false' do
        expect(node.required?).to be false
      end
    end
  end

  describe '#item_type' do
    context 'with items in array' do
      let(:node) { described_class.new }
      let(:item) { RailsOpenapiGen::AstNodes::ObjectNode.new(property_name: 'test_item') }

      before { node.add_item(item) }

      it 'returns object when items exist' do
        expect(node.item_type).to eq('object')
      end
    end

    context 'with comment data specifying item type' do
      let(:comment_data) { RailsOpenapiGen::AstNodes::CommentData.new(items: 'string') }
      let(:node) { described_class.new(comment_data: comment_data) }

      it 'returns specified type' do
        expect(node.item_type).to eq('string')
      end
    end

    context 'with comment data as hash' do
      let(:comment_data) { RailsOpenapiGen::AstNodes::CommentData.new(items: { type: 'integer' }) }
      let(:node) { described_class.new(comment_data: comment_data) }

      it 'extracts type from hash' do
        expect(node.item_type).to eq('integer')
      end
    end

    context 'without items or comment data' do
      let(:node) { described_class.new }

      it 'defaults to object' do
        expect(node.item_type).to eq('object')
      end
    end
  end

  describe '#to_h' do
    let(:comment_data) do
      RailsOpenapiGen::AstNodes::CommentData.new(
        type: 'array',
        description: 'List of orders'
      )
    end
    let(:node) do
      described_class.new(
        property_name: 'orders',
        comment_data: comment_data,
        is_conditional: false,
        is_root_array: true
      )
    end
    let(:item) do
      RailsOpenapiGen::AstNodes::ObjectNode.new(property_name: 'order')
    end

    before do
      node.add_item(item)
    end

    it 'includes all array attributes' do
      hash = node.to_h

      expect(hash).to include(
        property_name: 'orders',
        is_conditional: false,
        is_root_array: true,
        required: true,
        openapi_type: 'array',
        item_type: 'object',
        description: 'List of orders'
      )
    end

    it 'includes items as hash' do
      hash = node.to_h
      expect(hash[:items]).to be_an(Array)
      expect(hash[:items].first).to include(property_name: 'order')
    end

    it 'provides backward compatibility fields' do
      hash = node.to_h
      expect(hash[:array_item_properties]).to eq(hash[:items])
      expect(hash[:is_array_root]).to eq(true)
    end
  end

  describe '#accept' do
    let(:node) { described_class.new }
    let(:visitor) { double('visitor') }

    it 'calls visit_array on visitor' do
      expect(visitor).to receive(:visit_array).with(node)
      node.accept(visitor)
    end
  end
end
