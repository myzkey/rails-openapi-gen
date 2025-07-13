require 'spec_helper'

RSpec.describe RailsOpenapiGen::AstNodes::BaseNode do
  let(:node) { described_class.new }
  let(:child) { described_class.new }
  let(:metadata) { { test: 'value' } }

  describe '#initialize' do
    it 'initializes with empty children and metadata' do
      expect(node.children).to eq([])
      expect(node.metadata).to eq({})
    end

    it 'accepts parent and metadata' do
      parent = described_class.new
      node_with_data = described_class.new(parent: parent, metadata: metadata)

      expect(node_with_data.parent).to eq(parent)
      expect(node_with_data.metadata).to eq(metadata)
    end
  end

  describe '#add_child' do
    it 'adds a child node' do
      node.add_child(child)
      expect(node.children).to include(child)
    end

    it 'sets the parent of the child' do
      node.add_child(child)
      expect(child.parent).to eq(node)
    end

    it 'returns the added child' do
      result = node.add_child(child)
      expect(result).to eq(child)
    end
  end

  describe '#remove_child' do
    before { node.add_child(child) }

    it 'removes a child node' do
      node.remove_child(child)
      expect(node.children).not_to include(child)
    end

    it 'returns the removed child' do
      result = node.remove_child(child)
      expect(result).to eq(child)
    end
  end

  describe '#descendants' do
    let(:grandchild) { described_class.new }

    before do
      node.add_child(child)
      child.add_child(grandchild)
    end

    it 'returns all descendant nodes' do
      descendants = node.descendants
      expect(descendants).to include(child, grandchild)
      expect(descendants.size).to eq(2)
    end
  end

  describe '#leaf?' do
    it 'returns true for node with no children' do
      expect(node.leaf?).to be true
    end

    it 'returns false for node with children' do
      node.add_child(child)
      expect(node.leaf?).to be false
    end
  end

  describe '#root?' do
    it 'returns true for node with no parent' do
      expect(node.root?).to be true
    end

    it 'returns false for node with parent' do
      parent = described_class.new
      child = described_class.new(parent: parent)
      expect(child.root?).to be false
    end
  end

  describe '#root' do
    let(:grandparent) { described_class.new }
    let(:parent) { described_class.new(parent: grandparent) }
    let(:child) { described_class.new(parent: parent) }

    it 'returns self for root node' do
      expect(grandparent.root).to eq(grandparent)
    end

    it 'returns root node for descendant' do
      expect(child.root).to eq(grandparent)
    end
  end

  describe '#to_h' do
    it 'returns hash representation' do
      hash = node.to_h
      expect(hash).to include(:node_type, :metadata, :children)
      expect(hash[:node_type]).to eq('base')
      expect(hash[:metadata]).to eq({})
      expect(hash[:children]).to eq([])
    end

    it 'includes children in hash' do
      node.add_child(child)
      hash = node.to_h
      expect(hash[:children].size).to eq(1)
    end
  end

  describe '#accept' do
    let(:visitor) { double('visitor') }

    it 'calls visitor.visit with self' do
      expect(visitor).to receive(:visit).with(node)
      node.accept(visitor)
    end
  end

  describe '#pretty_print' do
    it 'prints node information' do
      expect { node.pretty_print }.to output(/BaseNode/).to_stdout
    end

    it 'prints children with indentation' do
      node.add_child(child)
      expect { node.pretty_print }.to output(/BaseNode.*\n\s+├─ BaseNode/m).to_stdout
    end
  end

  describe '#debug_line' do
    it 'returns single line representation' do
      line = node.debug_line
      expect(line).to include('BaseNode')
    end
  end

  describe '#summary_attributes' do
    context 'with property_name' do
      let(:node_with_name) do
        Class.new(described_class) do
          attr_reader :property_name

          def initialize(property_name: nil, **args)
            super(**args)
            @property_name = property_name
          end
        end.new(property_name: 'test_prop')
      end

      it 'includes property name in summary' do
        summary = node_with_name.summary_attributes
        expect(summary).to include('name=test_prop')
      end
    end

    context 'with children' do
      before { node.add_child(child) }

      it 'includes children count in summary' do
        summary = node.summary_attributes
        expect(summary).to include('children=1')
      end
    end
  end
end
