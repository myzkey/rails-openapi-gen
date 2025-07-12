# frozen_string_literal: true

require 'spec_helper'
require 'support/parser_ast_mocks'

RSpec.describe RailsOpenapiGen::Parsers::Jbuilder::Processors::ObjectProcessor do
  let(:file_path) { '/test/app/views/users/show.json.jbuilder' }
  let(:property_parser) { double('PropertyCommentParser') }
  let(:processor) { described_class.new(file_path, property_parser) }

  before do
    allow(property_parser).to receive(:find_property_comment_for_line).and_return(nil)
    
    # Mock JbuilderParser at the module level
    mock_jbuilder_parser_class = Class.new do
      def initialize(path)
        @jbuilder_path = path
      end
      
      def parse
        { properties: [{ name: 'partial_prop' }] }
      end
    end
    
    stub_const('RailsOpenapiGen::Parsers::Jbuilder::JbuilderParser', mock_jbuilder_parser_class)
    stub_const('RailsOpenapiGen::Parsers::Jbuilder::Processors::ObjectProcessor::JbuilderParser', mock_jbuilder_parser_class)
  end

  describe '#on_block' do
    let(:send_node) { double('send_node', children: [receiver, method_name]) }
    let(:args_node) { double('args_node') }
    let(:body) { double('body') }
    let(:node) { double('node', children: [send_node, args_node, body]) }
    let(:receiver) { nil }

    context 'with json property block without arguments (nested object)' do
      let(:method_name) { :profile }
      let(:args_node) { double('args_node', type: :args, children: []) }

      before do
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).with(receiver, method_name).and_return(true)
        allow(processor).to receive(:process_nested_object_block)
      end

      it 'processes nested object block' do
        expect(processor).to receive(:process_nested_object_block).with(node, 'profile')
        processor.on_block(node)
      end
    end

    context 'with json property block with nil args_node (nested object)' do
      let(:method_name) { :profile }
      let(:args_node) { nil }

      before do
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).with(receiver, method_name).and_return(true)
        allow(processor).to receive(:process_nested_object_block)
      end

      it 'processes nested object block' do
        expect(processor).to receive(:process_nested_object_block).with(node, 'profile')
        processor.on_block(node)
      end
    end

    context 'with json property block with arguments (array iteration)' do
      let(:method_name) { :tags }
      let(:args_node) { double('args_node', type: :args, children: [:tag]) }

      before do
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).with(receiver, method_name).and_return(true)
        allow(processor).to receive(:process_children)
      end

      it 'calls super for array blocks' do
        # Mock the super call to avoid actual AST processing
        allow_any_instance_of(RailsOpenapiGen::Parsers::Jbuilder::Processors::BaseProcessor).to receive(:on_block).and_return(node)
        
        result = processor.on_block(node)
        expect(result).to eq(node)
      end
    end

    context 'with array! method' do
      let(:method_name) { :array! }
      let(:args_node) { double('args_node', type: :args, children: []) }

      before do
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).with(receiver, method_name).and_return(true)
        allow(processor).to receive(:process_children)
      end

      it 'calls super for array! calls' do
        # Mock the super call to avoid actual AST processing
        allow_any_instance_of(RailsOpenapiGen::Parsers::Jbuilder::Processors::BaseProcessor).to receive(:on_block).and_return(node)
        
        result = processor.on_block(node)
        expect(result).to eq(node)
      end
    end

    context 'with non-json property block' do
      let(:method_name) { :unknown }

      before do
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).and_return(false)
        allow(processor).to receive(:process_children)
      end

      it 'calls super' do
        # Mock the super call to avoid actual AST processing
        allow_any_instance_of(RailsOpenapiGen::Parsers::Jbuilder::Processors::BaseProcessor).to receive(:on_block).and_return(node)
        
        result = processor.on_block(node)
        expect(result).to eq(node)
      end
    end
  end

  describe '#process_nested_object_block' do
    let(:args_node) { double('args_node') }
    let(:body) { double('body') }
    let(:node) { double('node', children: [nil, args_node, body], location: double(line: 10)) }
    let(:property_name) { 'profile' }
    let(:composite_processor) { double('CompositeProcessor', properties: [], partials: []) }

    before do
      allow(processor).to receive(:find_comment_for_node).and_return(nil)
      
      # Create a proper mock class for the composite processor
      mock_composite_class = Class.new do
        def initialize(file_path, property_parser)
        end
        
        def process(body)
        end
        
        def properties
          []
        end
        
        def partials
          []
        end
      end
      
      allow(described_class).to receive(:composite_processor_class).and_return(mock_composite_class)
      allow(processor).to receive(:add_property)
      allow(processor).to receive(:is_array_root_property).and_return(false)
      
      # Mock required classes
      stub_const('RailsOpenapiGen::AstNodes::CommentData', double)
      stub_const('RailsOpenapiGen::AstNodes::PropertyNodeFactory', double)
      allow(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).and_return(double('CommentData'))
      allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_object).and_return(double('ObjectNode'))
      allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_array).and_return(double('ArrayNode'))
    end

    it 'creates composite processor and processes body' do
      expect(described_class.composite_processor_class).to receive(:new).with(file_path, property_parser).and_call_original
      expect_any_instance_of(described_class.composite_processor_class).to receive(:process).with(body)
      
      processor.send(:process_nested_object_block, node, property_name)
    end

    it 'manages block stack correctly' do
      expect(processor).to receive(:push_block).with(:object)
      expect(processor).to receive(:pop_block)
      
      processor.send(:process_nested_object_block, node, property_name)
    end

    it 'creates object node with nested properties' do
      nested_properties = [{ name: 'nested_prop' }]
      allow(composite_processor).to receive(:properties).and_return(nested_properties)
      
      expect(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_object).with(
        property: property_name,
        comment_data: anything,
        nested_properties: nested_properties
      )
      
      processor.send(:process_nested_object_block, node, property_name)
    end

    context 'when nested properties contain only array root' do
      let(:array_root_property) { { property: 'items', is_array_root: true, array_item_properties: [] } }

      before do
        allow(composite_processor).to receive(:properties).and_return([array_root_property])
        allow(processor).to receive(:is_array_root_property).with(array_root_property).and_return(true)
        allow(processor).to receive(:get_array_item_properties).with(array_root_property).and_return([])
      end

      it 'creates array property instead of object' do
        expect(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_array).with(
          property: property_name,
          comment_data: anything,
          array_item_properties: []
        )
        
        processor.send(:process_nested_object_block, node, property_name)
      end

      it 'does not create object property' do
        expect(RailsOpenapiGen::AstNodes::PropertyNodeFactory).not_to receive(:create_object)
        processor.send(:process_nested_object_block, node, property_name)
      end
    end

    context 'with comment data' do
      let(:comment_data) { { type: 'object', description: 'User profile' } }

      before do
        allow(processor).to receive(:find_comment_for_node).with(node).and_return(comment_data)
      end

      it 'uses comment data for object creation' do
        expect(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).with(
          type: 'object'
        )
        
        processor.send(:process_nested_object_block, node, property_name)
      end
    end

    context 'with partials in block' do
      let(:partial_path) { '/test/partials/_profile.json.jbuilder' }

      before do
        allow(composite_processor).to receive(:partials).and_return([partial_path])
        allow(File).to receive(:exist?).with(partial_path).and_return(true)
        allow(processor).to receive(:parse_partial_for_nested_object).with(partial_path).and_return([{ name: 'partial_prop' }])
      end

      it 'processes partials and includes their properties' do
        expect(processor).to receive(:parse_partial_for_nested_object).with(partial_path)
        processor.send(:process_nested_object_block, node, property_name)
      end
    end
  end

  describe '#is_array_root_property' do
    context 'with hash property' do
      it 'returns true for array root with items property' do
        property = { property: 'items', is_array_root: true }
        result = processor.send(:is_array_root_property, property)
        expect(result).to be true
      end

      it 'returns true for array node type' do
        property = { property_name: 'items', node_type: 'array' }
        result = processor.send(:is_array_root_property, property)
        expect(result).to be true
      end

      it 'returns false for regular object property' do
        property = { property: 'name', type: 'string' }
        result = processor.send(:is_array_root_property, property)
        expect(result).to be false
      end
    end

    context 'with structured AST node' do
      let(:array_node) { double('ArrayNode', is_root_array: true, property_name: 'items') }
      let(:object_node) { double('ObjectNode', is_root_array: false, property_name: 'profile') }

      it 'returns true for array root nodes' do
        allow(array_node).to receive(:respond_to?).with(:is_root_array).and_return(true)
        allow(array_node).to receive(:respond_to?).with(:property_name).and_return(true)
        
        result = processor.send(:is_array_root_property, array_node)
        expect(result).to be true
      end

      it 'returns false for non-array nodes' do
        allow(object_node).to receive(:respond_to?).with(:is_root_array).and_return(true)
        allow(object_node).to receive(:respond_to?).with(:property_name).and_return(true)
        
        result = processor.send(:is_array_root_property, object_node)
        expect(result).to be false
      end
    end

    context 'with specific AST node types' do
      before do
        stub_const('RailsOpenapiGen::AstNodes::ArrayRootNode', Class.new)
        stub_const('RailsOpenapiGen::AstNodes::ArrayPropertyNode', Class.new)
      end

      let(:array_root_node) { RailsOpenapiGen::AstNodes::ArrayRootNode.new }
      let(:array_property_node) { double('ArrayPropertyNode', property: 'items') }

      it 'returns true for ArrayRootNode' do
        result = processor.send(:is_array_root_property, array_root_node)
        expect(result).to be true
      end

      it 'returns true for ArrayPropertyNode with items property' do
        allow(array_property_node).to receive(:is_a?).with(Hash).and_return(false)
        allow(array_property_node).to receive(:respond_to?).with(:is_root_array).and_return(false)
        allow(array_property_node).to receive(:is_a?).with(RailsOpenapiGen::AstNodes::ArrayRootNode).and_return(false)
        allow(array_property_node).to receive(:is_a?).with(RailsOpenapiGen::AstNodes::ArrayPropertyNode).and_return(true)
        
        result = processor.send(:is_array_root_property, array_property_node)
        expect(result).to be true
      end
    end
  end

  describe '#get_array_item_properties' do
    context 'with hash array node' do
      let(:array_node) { { array_item_properties: [{ name: 'item1' }, { name: 'item2' }] } }

      it 'returns array_item_properties from hash' do
        result = processor.send(:get_array_item_properties, array_node)
        expect(result).to eq([{ name: 'item1' }, { name: 'item2' }])
      end

      it 'returns empty array when no array_item_properties' do
        array_node = { other_property: 'value' }
        result = processor.send(:get_array_item_properties, array_node)
        expect(result).to eq([])
      end
    end

    context 'with structured AST node having children' do
      let(:array_node) { double('ArrayNode', children: [{ name: 'child1' }, { name: 'child2' }]) }

      it 'returns children as item properties' do
        allow(array_node).to receive(:respond_to?).with(:children).and_return(true)
        allow(array_node).to receive(:respond_to?).with(:array_item_properties).and_return(false)
        
        result = processor.send(:get_array_item_properties, array_node)
        expect(result).to eq([{ name: 'child1' }, { name: 'child2' }])
      end

      it 'returns empty array when children is nil' do
        allow(array_node).to receive(:respond_to?).with(:children).and_return(true)
        allow(array_node).to receive(:children).and_return(nil)
        
        result = processor.send(:get_array_item_properties, array_node)
        expect(result).to eq([])
      end
    end

    context 'with structured AST node having array_item_properties' do
      let(:array_node) { double('ArrayNode', array_item_properties: [{ name: 'prop1' }]) }

      it 'returns array_item_properties' do
        allow(array_node).to receive(:respond_to?).with(:children).and_return(false)
        allow(array_node).to receive(:respond_to?).with(:array_item_properties).and_return(true)
        
        result = processor.send(:get_array_item_properties, array_node)
        expect(result).to eq([{ name: 'prop1' }])
      end

      it 'returns empty array when array_item_properties is nil' do
        allow(array_node).to receive(:respond_to?).with(:children).and_return(false)
        allow(array_node).to receive(:array_item_properties).and_return(nil)
        
        result = processor.send(:get_array_item_properties, array_node)
        expect(result).to eq([])
      end
    end
  end

  describe 'context management' do
    let(:node) { double('node', children: [nil, nil, double('body')], location: double(line: 10)) }
    let(:property_name) { 'profile' }

    before do
      allow(processor).to receive(:find_comment_for_node).and_return(nil)
      
      # Create a proper mock class for the composite processor
      mock_composite_class = Class.new do
        def initialize(file_path, property_parser)
        end
        
        def process(body)
        end
        
        def properties
          []
        end
        
        def partials
          []
        end
      end
      
      allow(described_class).to receive(:composite_processor_class).and_return(mock_composite_class)
      allow(processor).to receive(:is_array_root_property).and_return(false)
      
      # Mock required classes
      stub_const('RailsOpenapiGen::AstNodes::CommentData', double)
      stub_const('RailsOpenapiGen::AstNodes::PropertyNodeFactory', double)
      allow(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).and_return(double)
      allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_object).and_return(double)
    end

    it 'preserves existing properties during object processing' do
      # Add some initial properties
      initial_property = { name: 'initial' }
      processor.properties << initial_property
      
      processor.send(:process_nested_object_block, node, property_name)
      
      # Should still have the initial property
      expect(processor.properties).to include(initial_property)
    end

    it 'preserves existing partials during object processing' do
      # Add some initial partials
      initial_partial = '/initial/partial.jbuilder'
      processor.partials << initial_partial
      
      processor.send(:process_nested_object_block, node, property_name)
      
      # Should still have the initial partial
      expect(processor.partials).to include(initial_partial)
    end

    it 'stores nested objects in @nested_objects' do
      nested_properties = [{ name: 'nested_prop' }]
      
      # Create a proper mock class for the composite processor
      mock_composite_class = Class.new do
        def initialize(file_path, property_parser)
        end
        
        def process(body)
        end
        
        def properties
          nested_properties
        end
        
        def partials
          []
        end
      end
      
      allow(described_class).to receive(:composite_processor_class).and_return(mock_composite_class)
      
      processor.send(:process_nested_object_block, node, property_name)
      
      expect(processor.instance_variable_get(:@nested_objects)[property_name]).to eq(nested_properties)
    end
  end

  describe 'debug logging' do
    let(:node) { double('node', children: [nil, nil, double('body')], location: double(line: 10)) }
    let(:property_name) { 'data' }
    let(:array_prop) { { property_name: 'items', is_array_root: true, node_type: 'array' } }

    before do
      allow(processor).to receive(:find_comment_for_node).and_return(nil)
      
      # Create a simple mock composite processor instance
      composite_processor_instance = double('CompositeProcessor')
      allow(composite_processor_instance).to receive(:process)
      allow(composite_processor_instance).to receive(:properties).and_return([array_prop])
      allow(composite_processor_instance).to receive(:partials).and_return([])
      
      # Create a proper mock class for the composite processor
      mock_composite_class = Class.new do
        def initialize(file_path, property_parser)
          # Mock constructor that accepts arguments
        end
      end
      
      allow(mock_composite_class).to receive(:new).and_return(composite_processor_instance)
      allow(described_class).to receive(:composite_processor_class).and_return(mock_composite_class)
      allow(processor).to receive(:is_array_root_property).and_return(true)
      allow(processor).to receive(:get_array_item_properties).and_return([])
      
      # Mock required classes
      stub_const('RailsOpenapiGen::AstNodes::CommentData', double)
      stub_const('RailsOpenapiGen::AstNodes::PropertyNodeFactory', double)
      allow(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).and_return(double)
      allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_array).and_return(double)
    end

    context 'when RAILS_OPENAPI_DEBUG is set' do
      before do
        allow(ENV).to receive(:[]).with('RAILS_OPENAPI_DEBUG').and_return('true')
      end

      it 'outputs debug information for array detection' do
        expect { processor.send(:process_nested_object_block, node, property_name) }.to output(/DEBUG/).to_stdout
      end
    end

    context 'when RAILS_OPENAPI_DEBUG is not set' do
      before do
        allow(ENV).to receive(:[]).with('RAILS_OPENAPI_DEBUG').and_return(nil)
      end

      it 'does not output debug information' do
        expect { processor.send(:process_nested_object_block, node, property_name) }.not_to output.to_stdout
      end
    end
  end

  describe 'integration with call detectors' do
    it 'uses JsonCallDetector for property detection' do
      send_node = double('send_node', children: [nil, :profile])
      args_node = double('args_node', type: :args, children: [])
      node = double('node', children: [send_node, args_node, double('body')])
      
      expect(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).with(nil, :profile)
      allow(processor).to receive(:process_nested_object_block)
      
      processor.on_block(node)
    end
  end

  describe 'edge cases' do
    context 'with empty nested properties' do
      let(:node) { double('node', children: [nil, nil, double('body')], location: double(line: 10)) }
      let(:property_name) { 'empty_object' }

      before do
        allow(processor).to receive(:find_comment_for_node).and_return(nil)
        
        # Create a proper mock class for the composite processor
        mock_composite_class = Class.new do
          def initialize(file_path, property_parser)
          end
          
          def process(body)
          end
          
          def properties
            []
          end
          
          def partials
            []
          end
        end
        
        allow(described_class).to receive(:composite_processor_class).and_return(mock_composite_class)
        allow(processor).to receive(:is_array_root_property).and_return(false)
        
        # Mock required classes
        stub_const('RailsOpenapiGen::AstNodes::CommentData', double)
        stub_const('RailsOpenapiGen::AstNodes::PropertyNodeFactory', double)
        allow(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).and_return(double)
        allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_object).and_return(double)
      end

      it 'creates object with empty nested properties' do
        expect(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_object).with(
          property: property_name,
          comment_data: anything,
          nested_properties: []
        )
        
        processor.send(:process_nested_object_block, node, property_name)
      end
    end

    context 'with multiple array properties in nested object' do
      let(:node) { double('node', children: [nil, nil, double('body')], location: double(line: 10)) }
      let(:property_name) { 'mixed_object' }
      let(:array_prop) { { property: 'items', is_array_root: true } }
      let(:string_prop) { { property: 'name', type: 'string' } }

      before do
        allow(processor).to receive(:find_comment_for_node).and_return(nil)
        
        # Create a proper mock class for the composite processor
        mock_composite_class = Class.new do
          def initialize(file_path, property_parser)
          end
          
          def process(body)
          end
          
          def properties
            [array_prop, string_prop]
          end
          
          def partials
            []
          end
        end
        
        allow(described_class).to receive(:composite_processor_class).and_return(mock_composite_class)
        allow(processor).to receive(:is_array_root_property).with(array_prop).and_return(true)
        allow(processor).to receive(:is_array_root_property).with(string_prop).and_return(false)
        
        # Mock required classes
        stub_const('RailsOpenapiGen::AstNodes::CommentData', double)
        stub_const('RailsOpenapiGen::AstNodes::PropertyNodeFactory', double)
        allow(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).and_return(double)
        allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_object).and_return(double)
      end

      it 'creates object when multiple properties exist (not just array root)' do
        expect(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_object).with(
          property: property_name,
          comment_data: anything,
          nested_properties: [array_prop, string_prop]
        )
        
        processor.send(:process_nested_object_block, node, property_name)
      end
    end
  end
end