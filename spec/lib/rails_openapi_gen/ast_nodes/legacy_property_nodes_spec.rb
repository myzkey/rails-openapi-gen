# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Legacy Property Node Classes' do
  let(:comment_data) { RailsOpenapiGen::AstNodes::CommentData.new(type: 'string', description: 'Test property') }

  describe RailsOpenapiGen::AstNodes::SimplePropertyNode do
    describe '#initialize' do
      it 'initializes with all attributes' do
        node = described_class.new(
          property: 'username',
          comment_data: comment_data,
          is_conditional: true
        )
        
        expect(node.property_name).to eq('username')
        expect(node.comment_data).to eq(comment_data)
        expect(node.is_conditional).to be true
      end

      it 'initializes with default values' do
        node = described_class.new(property: 'email')
        
        expect(node.property_name).to eq('email')
        expect(node.comment_data).to be_a(RailsOpenapiGen::AstNodes::CommentData)
        expect(node.is_conditional).to be false
      end
    end

    describe '#property' do
      it 'returns property_name for backward compatibility' do
        node = described_class.new(property: 'test_field')
        
        expect(node.property).to eq('test_field')
        expect(node.property).to eq(node.property_name)
      end
    end

    describe 'inheritance from PropertyNode' do
      it 'inherits all PropertyNode behavior' do
        node = described_class.new(property: 'name', comment_data: comment_data)
        
        expect(node).to be_a(RailsOpenapiGen::AstNodes::PropertyNode)
        expect(node).to respond_to(:required?)
        expect(node).to respond_to(:optional?)
        expect(node).to respond_to(:description)
        expect(node).to respond_to(:openapi_type)
        expect(node).to respond_to(:enum_values)
      end
    end

    describe 'backward compatibility' do
      it 'works with code expecting the old interface' do
        node = described_class.new(
          property: 'status',
          comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
            type: 'string',
            enum: ['active', 'inactive']
          )
        )
        
        # Old interface
        expect(node.property).to eq('status')
        
        # New interface still works
        expect(node.property_name).to eq('status')
        expect(node.enum_values).to eq(['active', 'inactive'])
      end
    end
  end

  describe RailsOpenapiGen::AstNodes::ArrayPropertyNode do
    describe '#initialize' do
      let(:item_properties) { [double('item1'), double('item2')] }

      it 'initializes with all attributes and items' do
        node = described_class.new(
          property: 'tags',
          comment_data: comment_data,
          is_conditional: true,
          array_item_properties: item_properties
        )
        
        expect(node.property_name).to eq('tags')
        expect(node.comment_data).to eq(comment_data)
        expect(node.is_conditional).to be true
        expect(node.items).to match_array(item_properties)
      end

      it 'initializes with empty items by default' do
        node = described_class.new(property: 'list')
        
        expect(node.property_name).to eq('list')
        expect(node.items).to be_empty
        expect(node.is_conditional).to be false
      end
    end

    describe 'legacy property methods' do
      let(:node) { described_class.new(property: 'items') }

      it '#property returns property_name' do
        expect(node.property).to eq('items')
        expect(node.property).to eq(node.property_name)
      end

      it '#array_item_properties returns items' do
        item1 = double('item1')
        item2 = double('item2')
        node.add_item(item1)
        node.add_item(item2)
        
        expect(node.array_item_properties).to match_array([item1, item2])
        expect(node.array_item_properties).to eq(node.items)
      end

      it '#add_item_property delegates to add_item' do
        item = double('item')
        
        expect(node).to receive(:add_item).with(item)
        node.add_item_property(item)
      end
    end

    describe 'inheritance from ArrayNode' do
      it 'inherits all ArrayNode behavior' do
        node = described_class.new(property: 'data')
        
        expect(node).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
        expect(node).to respond_to(:add_item)
        expect(node).to respond_to(:item_type)
        expect(node).to respond_to(:required?)
        expect(node.is_root_array).to be false
      end
    end

    describe 'backward compatibility' do
      it 'works with old array processing code' do
        node = described_class.new(property: 'users')
        
        # Old methods
        user_item = double('user_item')
        node.add_item_property(user_item)
        
        expect(node.property).to eq('users')
        expect(node.array_item_properties).to include(user_item)
        
        # New methods still work
        expect(node.property_name).to eq('users')
        expect(node.items).to include(user_item)
      end
    end
  end

  describe RailsOpenapiGen::AstNodes::ObjectPropertyNode do
    describe '#initialize' do
      let(:nested_properties) { [double('prop1'), double('prop2')] }

      it 'initializes with all attributes and nested properties' do
        node = described_class.new(
          property: 'profile',
          comment_data: comment_data,
          is_conditional: true,
          nested_properties: nested_properties
        )
        
        expect(node.property_name).to eq('profile')
        expect(node.comment_data).to eq(comment_data)
        expect(node.is_conditional).to be true
        expect(node.properties).to match_array(nested_properties)
      end

      it 'initializes with empty properties by default' do
        node = described_class.new(property: 'data')
        
        expect(node.property_name).to eq('data')
        expect(node.properties).to be_empty
        expect(node.is_conditional).to be false
      end
    end

    describe 'legacy property methods' do
      let(:node) { described_class.new(property: 'object') }

      it '#property returns property_name' do
        expect(node.property).to eq('object')
        expect(node.property).to eq(node.property_name)
      end

      it '#nested_properties returns properties' do
        prop1 = double('prop1')
        prop2 = double('prop2')
        node.add_property(prop1)
        node.add_property(prop2)
        
        expect(node.nested_properties).to match_array([prop1, prop2])
        expect(node.nested_properties).to eq(node.properties)
      end

      it '#add_nested_property delegates to add_property' do
        prop = double('property')
        
        expect(node).to receive(:add_property).with(prop)
        node.add_nested_property(prop)
      end
    end

    describe 'inheritance from ObjectNode' do
      it 'inherits all ObjectNode behavior' do
        node = described_class.new(property: 'user')
        
        expect(node).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
        expect(node).to respond_to(:add_property)
        expect(node).to respond_to(:required?)
        expect(node).to respond_to(:description)
      end
    end

    describe 'backward compatibility' do
      it 'works with old object processing code' do
        node = described_class.new(property: 'user')
        
        # Old methods
        name_prop = double('name_property')
        node.add_nested_property(name_prop)
        
        expect(node.property).to eq('user')
        expect(node.nested_properties).to include(name_prop)
        
        # New methods still work
        expect(node.property_name).to eq('user')
        expect(node.properties).to include(name_prop)
      end
    end
  end

  describe RailsOpenapiGen::AstNodes::ArrayRootNode do
    describe '#initialize' do
      let(:item_properties) { [double('item1'), double('item2')] }

      it 'initializes as root array with items' do
        node = described_class.new(
          comment_data: comment_data,
          array_item_properties: item_properties
        )
        
        expect(node.property_name).to eq('items')
        expect(node.comment_data).to eq(comment_data)
        expect(node.is_root_array).to be true
        expect(node.items).to match_array(item_properties)
      end

      it 'initializes with empty items by default' do
        node = described_class.new
        
        expect(node.property_name).to eq('items')
        expect(node.is_root_array).to be true
        expect(node.items).to be_empty
      end
    end

    describe 'legacy property methods' do
      let(:node) { described_class.new }

      it '#property returns property_name' do
        expect(node.property).to eq('items')
        expect(node.property).to eq(node.property_name)
      end

      it '#array_item_properties returns items' do
        item1 = double('item1')
        item2 = double('item2')
        node.add_item(item1)
        node.add_item(item2)
        
        expect(node.array_item_properties).to match_array([item1, item2])
        expect(node.array_item_properties).to eq(node.items)
      end

      it '#add_item_property delegates to add_item' do
        item = double('item')
        
        expect(node).to receive(:add_item).with(item)
        node.add_item_property(item)
      end
    end

    describe 'root array characteristics' do
      it 'is always a root array' do
        node = described_class.new
        expect(node.is_root_array).to be true
      end

      it 'has fixed property_name of items' do
        node = described_class.new
        expect(node.property_name).to eq('items')
        expect(node.property).to eq('items')
      end
    end

    describe 'inheritance from ArrayNode' do
      it 'inherits all ArrayNode behavior' do
        node = described_class.new
        
        expect(node).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
        expect(node).to respond_to(:add_item)
        expect(node).to respond_to(:item_type)
        expect(node).to respond_to(:required?)
      end
    end

    describe 'backward compatibility' do
      it 'works with old root array processing code' do
        node = described_class.new
        
        # Old methods
        item = double('array_item')
        node.add_item_property(item)
        
        expect(node.property).to eq('items')
        expect(node.array_item_properties).to include(item)
        
        # New methods still work
        expect(node.property_name).to eq('items')
        expect(node.items).to include(item)
        expect(node.is_root_array).to be true
      end
    end
  end

  describe 'cross-compatibility between legacy classes' do
    it 'allows mixing legacy and new node types' do
      # Create using legacy classes
      simple_prop = RailsOpenapiGen::AstNodes::SimplePropertyNode.new(
        property: 'name',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'string')
      )
      
      array_prop = RailsOpenapiGen::AstNodes::ArrayPropertyNode.new(
        property: 'tags',
        array_item_properties: [simple_prop]
      )
      
      object_prop = RailsOpenapiGen::AstNodes::ObjectPropertyNode.new(
        property: 'user',
        nested_properties: [simple_prop, array_prop]
      )
      
      root_array = RailsOpenapiGen::AstNodes::ArrayRootNode.new(
        array_item_properties: [object_prop]
      )
      
      # Verify relationships work correctly
      expect(root_array.items).to include(object_prop)
      expect(object_prop.properties).to include(simple_prop, array_prop)
      expect(array_prop.items).to include(simple_prop)
      
      # Verify both old and new interfaces work
      expect(root_array.property).to eq('items')
      expect(object_prop.property).to eq('user')
      expect(array_prop.property).to eq('tags')
      expect(simple_prop.property).to eq('name')
      
      expect(root_array.property_name).to eq('items')
      expect(object_prop.property_name).to eq('user')
      expect(array_prop.property_name).to eq('tags')
      expect(simple_prop.property_name).to eq('name')
    end

    it 'supports complex nested structures with legacy classes' do
      # Build a complex structure: users array with user objects containing profile objects
      profile_name = RailsOpenapiGen::AstNodes::SimplePropertyNode.new(
        property: 'full_name',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'string')
      )
      
      profile_object = RailsOpenapiGen::AstNodes::ObjectPropertyNode.new(
        property: 'profile',
        nested_properties: [profile_name]
      )
      
      user_id = RailsOpenapiGen::AstNodes::SimplePropertyNode.new(
        property: 'id',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(type: 'integer')
      )
      
      user_object = RailsOpenapiGen::AstNodes::ObjectPropertyNode.new(
        property: 'user',
        nested_properties: [user_id, profile_object]
      )
      
      users_array = RailsOpenapiGen::AstNodes::ArrayRootNode.new(
        array_item_properties: [user_object]
      )
      
      # Verify the structure
      expect(users_array.array_item_properties.first.property).to eq('user')
      expect(user_object.nested_properties.map(&:property)).to include('id', 'profile')
      expect(profile_object.nested_properties.first.property).to eq('full_name')
    end
  end

  describe 'deprecation pathway' do
    it 'provides clear migration path from legacy to new classes' do
      # Show how legacy code can be migrated
      
      # Old way (legacy)
      legacy_node = RailsOpenapiGen::AstNodes::SimplePropertyNode.new(
        property: 'test',
        comment_data: comment_data
      )
      
      # New way (recommended)
      new_node = RailsOpenapiGen::AstNodes::NodeFactory.create_property(
        property_name: 'test',
        comment_data: comment_data
      )
      
      # Both produce equivalent results
      expect(legacy_node.property_name).to eq(new_node.property_name)
      expect(legacy_node.comment_data).to eq(new_node.comment_data)
      expect(legacy_node.class.superclass).to eq(new_node.class)
    end
  end
end