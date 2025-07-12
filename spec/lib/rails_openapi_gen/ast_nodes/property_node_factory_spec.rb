# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsOpenapiGen::AstNodes::PropertyNodeFactory do
  let(:comment_data) { RailsOpenapiGen::AstNodes::CommentData.new(type: 'string', description: 'Test property') }

  describe '.from_hash' do
    it 'delegates to NodeFactory.from_hash' do
      hash_data = { property_name: 'test', type: 'string' }
      
      expect(RailsOpenapiGen::AstNodes::NodeFactory).to receive(:from_hash).with(hash_data)
      described_class.from_hash(hash_data)
    end
  end

  describe '.create_simple' do
    it 'creates a PropertyNode with correct attributes' do
      result = described_class.create_simple(
        property: 'username',
        comment_data: comment_data,
        is_conditional: true
      )
      
      expect(result).to be_a(RailsOpenapiGen::AstNodes::PropertyNode)
      expect(result.property_name).to eq('username')
      expect(result.comment_data).to eq(comment_data)
      expect(result.is_conditional).to be true
    end

    it 'creates PropertyNode with default values' do
      result = described_class.create_simple(property: 'email')
      
      expect(result).to be_a(RailsOpenapiGen::AstNodes::PropertyNode)
      expect(result.property_name).to eq('email')
      expect(result.comment_data).to be_a(RailsOpenapiGen::AstNodes::CommentData)
      expect(result.is_conditional).to be false
    end

    it 'delegates to NodeFactory.create_property' do
      expect(RailsOpenapiGen::AstNodes::NodeFactory).to receive(:create_property).with(
        property_name: 'test_prop',
        comment_data: comment_data,
        is_conditional: true
      )
      
      described_class.create_simple(
        property: 'test_prop',
        comment_data: comment_data,
        is_conditional: true
      )
    end
  end

  describe '.create_array' do
    let(:item_properties) { [double('item1'), double('item2')] }

    it 'creates an ArrayNode with items' do
      result = described_class.create_array(
        property: 'tags',
        comment_data: comment_data,
        is_conditional: true,
        array_item_properties: item_properties
      )
      
      expect(result).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
      expect(result.property_name).to eq('tags')
      expect(result.comment_data).to eq(comment_data)
      expect(result.is_conditional).to be true
      expect(result.items).to match_array(item_properties)
    end

    it 'creates ArrayNode with empty items by default' do
      result = described_class.create_array(property: 'items')
      
      expect(result).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
      expect(result.property_name).to eq('items')
      expect(result.items).to be_empty
    end

    it 'adds each item property to the array' do
      array_node = double('ArrayNode')
      allow(RailsOpenapiGen::AstNodes::NodeFactory).to receive(:create_array).and_return(array_node)
      
      item_properties.each do |item|
        expect(array_node).to receive(:add_item).with(item)
      end
      
      described_class.create_array(
        property: 'test_array',
        array_item_properties: item_properties
      )
    end
  end

  describe '.create_object' do
    let(:nested_properties) { [double('prop1'), double('prop2')] }

    it 'creates an ObjectNode with nested properties' do
      result = described_class.create_object(
        property: 'profile',
        comment_data: comment_data,
        is_conditional: true,
        nested_properties: nested_properties
      )
      
      expect(result).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
      expect(result.property_name).to eq('profile')
      expect(result.comment_data).to eq(comment_data)
      expect(result.is_conditional).to be true
      expect(result.properties).to match_array(nested_properties)
    end

    it 'creates ObjectNode with empty properties by default' do
      result = described_class.create_object(property: 'data')
      
      expect(result).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
      expect(result.property_name).to eq('data')
      expect(result.properties).to be_empty
    end

    it 'adds each nested property to the object' do
      object_node = double('ObjectNode')
      allow(RailsOpenapiGen::AstNodes::NodeFactory).to receive(:create_object).and_return(object_node)
      
      nested_properties.each do |prop|
        expect(object_node).to receive(:add_property).with(prop)
      end
      
      described_class.create_object(
        property: 'test_object',
        nested_properties: nested_properties
      )
    end
  end

  describe '.create_array_root' do
    let(:item_properties) { [double('item1'), double('item2')] }

    it 'creates a root ArrayNode with items' do
      result = described_class.create_array_root(
        comment_data: comment_data,
        array_item_properties: item_properties
      )
      
      expect(result).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
      expect(result.is_root_array).to be true
      expect(result.comment_data).to eq(comment_data)
      expect(result.items).to match_array(item_properties)
    end

    it 'creates root ArrayNode with empty items by default' do
      result = described_class.create_array_root
      
      expect(result).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
      expect(result.is_root_array).to be true
      expect(result.items).to be_empty
    end

    it 'delegates to NodeFactory with is_root_array: true' do
      expect(RailsOpenapiGen::AstNodes::NodeFactory).to receive(:create_array).with(
        comment_data: comment_data,
        is_root_array: true
      ).and_return(double('ArrayNode', add_item: nil))
      
      described_class.create_array_root(comment_data: comment_data)
    end

    it 'adds each item property to the root array' do
      array_node = double('ArrayNode')
      allow(RailsOpenapiGen::AstNodes::NodeFactory).to receive(:create_array).and_return(array_node)
      
      item_properties.each do |item|
        expect(array_node).to receive(:add_item).with(item)
      end
      
      described_class.create_array_root(array_item_properties: item_properties)
    end
  end

  describe 'backward compatibility' do
    it 'maintains the same interface as the original PropertyNodeFactory' do
      # Test that all expected methods exist
      expect(described_class).to respond_to(:from_hash)
      expect(described_class).to respond_to(:create_simple)
      expect(described_class).to respond_to(:create_array)
      expect(described_class).to respond_to(:create_object)
      expect(described_class).to respond_to(:create_array_root)
    end

    it 'works with existing code patterns' do
      # Test a typical usage pattern from the old code
      simple_prop = described_class.create_simple(
        property: 'name',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'string')
      )
      
      array_prop = described_class.create_array(
        property: 'tags',
        array_item_properties: [simple_prop]
      )
      
      object_prop = described_class.create_object(
        property: 'user',
        nested_properties: [simple_prop, array_prop]
      )
      
      expect(simple_prop).to be_a(RailsOpenapiGen::AstNodes::PropertyNode)
      expect(array_prop).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
      expect(object_prop).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
      
      expect(array_prop.items).to include(simple_prop)
      expect(object_prop.properties).to include(simple_prop, array_prop)
    end
  end

  describe 'integration with NodeFactory' do
    it 'produces the same results as calling NodeFactory directly' do
      # Test create_simple
      factory_result = RailsOpenapiGen::AstNodes::NodeFactory.create_property(
        property_name: 'test',
        comment_data: comment_data
      )
      legacy_result = described_class.create_simple(
        property: 'test',
        comment_data: comment_data
      )
      
      expect(legacy_result.class).to eq(factory_result.class)
      expect(legacy_result.property_name).to eq(factory_result.property_name)
      expect(legacy_result.comment_data).to eq(factory_result.comment_data)
    end

    it 'maintains consistency between factory methods' do
      # Create nodes using both approaches
      direct_array = RailsOpenapiGen::AstNodes::NodeFactory.create_array(
        property_name: 'items',
        is_root_array: true
      )
      
      legacy_array = described_class.create_array_root
      
      expect(direct_array.is_root_array).to eq(legacy_array.is_root_array)
      expect(direct_array.class).to eq(legacy_array.class)
      expect(direct_array.property_name).to eq(legacy_array.property_name)
    end
  end
end