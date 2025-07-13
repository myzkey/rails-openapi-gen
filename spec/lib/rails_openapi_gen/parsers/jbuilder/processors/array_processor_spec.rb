# frozen_string_literal: true

require 'spec_helper'
require 'support/parser_ast_mocks'

RSpec.describe RailsOpenapiGen::Parsers::Jbuilder::Processors::ArrayProcessor do
  let(:file_path) { '/test/app/views/users/index.json.jbuilder' }
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
        # Return a simple hash that responds to [:properties]
        { properties: [{ name: 'partial_prop' }] }
      end
    end

    stub_const('RailsOpenapiGen::Parsers::Jbuilder::JbuilderParser', mock_jbuilder_parser_class)
    # Also mock the local constant in ArrayProcessor
    stub_const('RailsOpenapiGen::Parsers::Jbuilder::Processors::ArrayProcessor::JbuilderParser',
               mock_jbuilder_parser_class)
  end

  describe '#on_send' do
    let(:receiver) { nil }
    let(:args) { [] }
    let(:node) { double('node', children: [receiver, method_name, *args]) }

    context 'with array! method call' do
      let(:method_name) { :array! }

      before do
        allow(described_class::CallDetectors::ArrayCallDetector).to receive(:array_call?).with(receiver,
                                                                                               method_name).and_return(true)
        allow(described_class::CallDetectors::ArrayCallDetector).to receive(:has_partial_key?).and_return(false)
        allow(processor).to receive(:process_array_property)
        allow(node).to receive(:updated).and_return(node)
      end

      it 'processes array property when no partial arguments' do
        expect(processor).to receive(:process_array_property).with(node)
        processor.on_send(node)
      end

      it 'calls super to continue processing' do
        allow(node).to receive(:updated).and_return(node)
        expect { processor.on_send(node) }.not_to raise_error
      end
    end

    context 'with array! method call with partial argument' do
      let(:method_name) { :array! }
      let(:hash_arg) { double('hash_arg', type: :hash) }
      let(:args) { [hash_arg] }

      before do
        allow(described_class::CallDetectors::ArrayCallDetector).to receive(:array_call?).with(receiver,
                                                                                               method_name).and_return(true)
        allow(described_class::CallDetectors::ArrayCallDetector).to receive(:has_partial_key?).with(hash_arg).and_return(true)
        allow(processor).to receive(:process_array_with_partial)
        allow(node).to receive(:updated).and_return(node)
      end

      it 'processes array with partial' do
        expect(processor).to receive(:process_array_with_partial).with(node, args)
        processor.on_send(node)
      end
    end

    context 'with non-array method call' do
      let(:method_name) { :name }

      before do
        allow(described_class::CallDetectors::ArrayCallDetector).to receive(:array_call?).and_return(false)
        allow(processor).to receive(:process_children)
      end

      it 'calls super without processing array logic' do
        expect(processor).not_to receive(:process_array_property)
        allow(node).to receive(:updated).and_return(node)
        expect { processor.on_send(node) }.not_to raise_error
      end
    end
  end

  describe '#on_block' do
    let(:send_node) { double('send_node', children: [receiver, method_name]) }
    let(:args_node) { double('args_node') }
    let(:body) { double('body') }
    let(:node) { double('node', children: [send_node, args_node, body]) }
    let(:receiver) { nil }

    context 'with array! block' do
      let(:method_name) { :array! }

      before do
        allow(described_class::CallDetectors::ArrayCallDetector).to receive(:array_call?).with(receiver,
                                                                                               method_name).and_return(true)
        allow(processor).to receive(:process_array_block)
      end

      it 'processes array block' do
        expect(processor).to receive(:process_array_block).with(node)
        processor.on_block(node)
      end
    end

    context 'with array iteration block (with arguments)' do
      let(:method_name) { :tags }
      let(:args_node) { double('args_node', type: :args, children: [:tag]) }

      before do
        allow(described_class::CallDetectors::ArrayCallDetector).to receive(:array_call?).and_return(false)
        allow(described_class::CallDetectors::JsonCallDetector).to receive(:json_property?).with(receiver,
                                                                                                 method_name).and_return(true)
        allow(processor).to receive(:process_array_iteration_block)
      end

      it 'processes array iteration block' do
        expect(processor).to receive(:process_array_iteration_block).with(node, 'tags')
        processor.on_block(node)
      end
    end

    context 'with json property block without arguments' do
      let(:method_name) { :profile }
      let(:args_node) { double('args_node', type: :args, children: []) }

      before do
        allow(described_class::CallDetectors::ArrayCallDetector).to receive(:array_call?).and_return(false)
        allow(described_class::CallDetectors::JsonCallDetector).to receive(:json_property?).with(receiver,
                                                                                                 method_name).and_return(true)
        allow(processor).to receive(:process_children)
      end

      it 'calls super for non-array blocks' do
        # Since this is testing the logic path, we can verify that process_array_iteration_block is NOT called
        expect(processor).not_to receive(:process_array_iteration_block)
        expect(processor).not_to receive(:process_array_block)

        # Mock the super call to avoid actual AST processing
        allow_any_instance_of(RailsOpenapiGen::Parsers::Jbuilder::Processors::BaseProcessor).to receive(:on_block).and_return(node)

        result = processor.on_block(node)
        expect(result).to eq(node)
      end
    end

    context 'with unknown block' do
      let(:method_name) { :unknown }

      before do
        allow(described_class::CallDetectors::ArrayCallDetector).to receive(:array_call?).and_return(false)
        allow(described_class::CallDetectors::JsonCallDetector).to receive(:json_property?).and_return(false)
        allow(processor).to receive(:process_children)
      end

      it 'calls super' do
        # Since this is testing the logic path, we can verify that no special processing is called
        expect(processor).not_to receive(:process_array_iteration_block)
        expect(processor).not_to receive(:process_array_block)

        # Mock the super call to avoid actual AST processing
        allow_any_instance_of(RailsOpenapiGen::Parsers::Jbuilder::Processors::BaseProcessor).to receive(:on_block).and_return(node)

        result = processor.on_block(node)
        expect(result).to eq(node)
      end
    end
  end

  describe '#process_array_block' do
    let(:node) { double('node', children: [nil, nil, body], location: double(line: 10)) }
    let(:body) { double('body') }
    let(:composite_processor) { double('CompositeProcessor', properties: [], partials: []) }

    before do
      allow(processor).to receive(:find_comment_for_node).and_return(nil)

      # Create a proper mock class for the composite processor
      mock_composite_class = Class.new do
        def initialize(file_path, property_parser); end

        def process(body); end

        def properties
          []
        end

        def partials
          []
        end
      end

      allow(described_class).to receive(:composite_processor_class).and_return(mock_composite_class)
      allow(processor).to receive(:add_property)

      # Mock AstNodes classes
      stub_const('RailsOpenapiGen::AstNodes::CommentData', double)
      stub_const('RailsOpenapiGen::AstNodes::PropertyNodeFactory', double)
      allow(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).and_return(double('CommentData'))
      allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_array_root).and_return(double('ArrayRootNode'))
      allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:from_hash).and_return(double('PropertyNode'))
    end

    it 'creates composite processor and processes body' do
      expect(described_class.composite_processor_class).to receive(:new).with(file_path,
                                                                              property_parser).and_call_original
      expect_any_instance_of(described_class.composite_processor_class).to receive(:process).with(body)

      processor.send(:process_array_block, node)
    end

    it 'manages block stack correctly' do
      expect(processor).to receive(:push_block).with(:array)
      expect(processor).to receive(:pop_block)

      processor.send(:process_array_block, node)
    end

    it 'creates array root node with processed properties' do
      allow(composite_processor).to receive(:properties).and_return([{ name: 'test' }])

      expect(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_array_root).with(
        comment_data: anything,
        array_item_properties: anything
      )

      processor.send(:process_array_block, node)
    end

    context 'with partials in block' do
      let(:partial_path) { '/test/partials/_user.json.jbuilder' }

      before do
        # Create a mock class that returns partials
        mock_composite_class_with_partials = Class.new do
          def initialize(file_path, property_parser); end

          def process(body); end

          def properties
            []
          end

          def partials
            ['/test/partials/_user.json.jbuilder']
          end
        end

        allow(described_class).to receive(:composite_processor_class).and_return(mock_composite_class_with_partials)
        allow(File).to receive(:exist?).with(partial_path).and_return(true)
        allow(processor).to receive(:parse_partial_for_nested_object).with(partial_path).and_return([{ name: 'partial_prop' }])
      end

      it 'processes partials and includes their properties' do
        expect(processor).to receive(:parse_partial_for_nested_object).with(partial_path)
        processor.send(:process_array_block, node)
      end
    end

    context 'with comment data' do
      let(:comment_data) { { type: 'array', items: { type: 'object' }, description: 'Array of items' } }

      before do
        allow(processor).to receive(:find_comment_for_node).with(node).and_return(comment_data)
      end

      it 'uses comment data for array node creation' do
        expect(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).with(
          type: 'array',
          items: { type: 'object' }
        )

        processor.send(:process_array_block, node)
      end
    end
  end

  describe '#process_array_property' do
    let(:node) { double('node', location: double(line: 5)) }
    let(:comment_data) { { type: 'array', description: 'Array property' } }

    before do
      allow(processor).to receive(:find_comment_for_node).with(node).and_return(comment_data)
      allow(processor).to receive(:add_property)
    end

    it 'creates array property with comment data' do
      expected_property = {
        node_type: 'array',
        property: 'items',
        comment_data: comment_data,
        is_array_root: true
      }

      expect(processor).to receive(:add_property).with(expected_property)
      processor.send(:process_array_property, node)
    end

    context 'without comment data' do
      before do
        allow(processor).to receive(:find_comment_for_node).with(node).and_return(nil)
      end

      it 'creates array property with default comment data' do
        expected_property = {
          node_type: 'array',
          property: 'items',
          comment_data: { type: 'array', items: { type: 'object' } },
          is_array_root: true
        }

        expect(processor).to receive(:add_property).with(expected_property)
        processor.send(:process_array_property, node)
      end
    end
  end

  describe '#process_array_with_partial' do
    let(:node) { double('node') }
    let(:partial_str_node) { double('str_node', type: :str, children: ['user']) }
    let(:partial_key_node) { double('key_node', type: :sym, children: [:partial]) }
    let(:pair_node) { double('pair_node', type: :pair, children: [partial_key_node, partial_str_node]) }
    let(:hash_node) { double('hash_node', type: :hash, children: [pair_node]) }
    let(:args) { [hash_node] }
    let(:resolved_path) { '/test/app/views/users/_user.json.jbuilder' }

    before do
      allow(processor).to receive(:resolve_partial_path).with('user').and_return(resolved_path)
      allow(File).to receive(:exist?).with(resolved_path).and_return(true)
      allow(processor).to receive(:add_property)
    end

    it 'extracts partial path from hash arguments' do
      expect(processor).to receive(:resolve_partial_path).with('user')
      processor.send(:process_array_with_partial, node, args)
    end

    it 'creates array property with partial properties' do
      expected_property = {
        node_type: 'array',
        property: 'items',
        comment_data: { type: 'array' },
        is_array_root: true,
        array_item_properties: [{ name: 'partial_prop' }]
      }

      expect(processor).to receive(:add_property).with(expected_property)
      processor.send(:process_array_with_partial, node, args)
    end

    context 'when partial file does not exist' do
      before do
        allow(File).to receive(:exist?).with(resolved_path).and_return(false)
        allow(processor).to receive(:process_array_property)
      end

      it 'falls back to regular array processing' do
        expect(processor).to receive(:process_array_property).with(node)
        processor.send(:process_array_with_partial, node, args)
      end
    end

    context 'when no partial path found in arguments' do
      let(:other_pair) do
        double('pair', type: :pair,
                       children: [double(type: :sym, children: [:other]), double(type: :str, children: ['value'])])
      end
      let(:hash_node) { double('hash_node', type: :hash, children: [other_pair]) }

      before do
        allow(processor).to receive(:process_array_property)
      end

      it 'falls back to regular array processing' do
        expect(processor).to receive(:process_array_property).with(node)
        processor.send(:process_array_with_partial, node, args)
      end
    end
  end

  describe '#process_array_iteration_block' do
    let(:args_node) { double('args_node') }
    let(:body) { double('body') }
    let(:node) { double('node', children: [nil, args_node, body], location: double(line: 15)) }
    let(:property_name) { 'tags' }
    let(:composite_processor) { double('CompositeProcessor', properties: [], partials: []) }

    before do
      allow(processor).to receive(:find_comment_for_node).and_return(nil)
      allow(described_class).to receive(:composite_processor_class).and_return(double)
      allow(described_class.composite_processor_class).to receive(:new).and_return(composite_processor)
      allow(composite_processor).to receive(:process)
      allow(processor).to receive(:add_property)
    end

    it 'processes block body with composite processor' do
      expect(described_class.composite_processor_class).to receive(:new).with(file_path, property_parser)
      expect(composite_processor).to receive(:process).with(body)

      processor.send(:process_array_iteration_block, node, property_name)
    end

    it 'creates array property with correct name' do
      expected_property = {
        node_type: 'property',
        property: 'tags',
        comment_data: { type: 'array' },
        is_array: true,
        array_item_properties: []
      }

      expect(processor).to receive(:add_property).with(expected_property)
      processor.send(:process_array_iteration_block, node, property_name)
    end

    it 'manages block stack during processing' do
      expect(processor).to receive(:push_block).with(:array)
      expect(processor).to receive(:pop_block)

      processor.send(:process_array_iteration_block, node, property_name)
    end

    context 'with comment data' do
      let(:comment_data) { { type: 'array', items: { type: 'string' } } }

      before do
        allow(processor).to receive(:find_comment_for_node).and_return(comment_data)
      end

      it 'uses provided comment data' do
        expected_property = hash_including(comment_data: comment_data)
        expect(processor).to receive(:add_property).with(expected_property)

        processor.send(:process_array_iteration_block, node, property_name)
      end
    end
  end

  describe 'context management' do
    let(:node) { double('node', children: [nil, nil, double('body')], location: double(line: 10)) }

    before do
      allow(processor).to receive(:find_comment_for_node).and_return(nil)

      # Create a more properly mocked composite processor class
      composite_processor_class = double('CompositeProcessorClass')
      composite_processor_instance = double('CompositeProcessor', properties: [], partials: [])

      allow(described_class).to receive(:composite_processor_class).and_return(composite_processor_class)
      allow(composite_processor_class).to receive(:new).and_return(composite_processor_instance)
      allow(composite_processor_instance).to receive(:process)

      # Mock required classes
      stub_const('RailsOpenapiGen::AstNodes::CommentData', double)
      stub_const('RailsOpenapiGen::AstNodes::PropertyNodeFactory', double)
      allow(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).and_return(double)
      allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_array_root).and_return(double)
    end

    it 'preserves existing properties during array processing' do
      # Add some initial properties
      initial_property = { name: 'initial' }
      processor.properties << initial_property

      processor.send(:process_array_block, node)

      # Should still have the initial property
      expect(processor.properties).to include(initial_property)
    end

    it 'preserves existing partials during array processing' do
      # Add some initial partials
      initial_partial = '/initial/partial.jbuilder'
      processor.partials << initial_partial

      processor.send(:process_array_block, node)

      # Should still have the initial partial
      expect(processor.partials).to include(initial_partial)
    end
  end

  describe 'debug logging' do
    let(:node) { double('node', children: [nil, nil, double('body')], location: double(line: 10)) }

    before do
      allow(processor).to receive(:find_comment_for_node).and_return(nil)

      # Create a proper mock class for the composite processor
      mock_composite_class = Class.new do
        def initialize(file_path, property_parser); end

        def process(body); end

        def properties
          []
        end

        def partials
          ['/test/partial.jbuilder']
        end
      end

      allow(described_class).to receive(:composite_processor_class).and_return(mock_composite_class)
      allow(File).to receive(:exist?).and_return(true)
      allow(processor).to receive(:parse_partial_for_nested_object).and_return([])

      # Mock required classes
      stub_const('RailsOpenapiGen::AstNodes::CommentData', double)
      stub_const('RailsOpenapiGen::AstNodes::PropertyNodeFactory', double)
      allow(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).and_return(double)
      allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_array_root).and_return(double)
    end

    context 'when RAILS_OPENAPI_DEBUG is set' do
      before do
        allow(ENV).to receive(:[]).with('RAILS_OPENAPI_DEBUG').and_return('true')
      end

      it 'outputs debug information' do
        expect { processor.send(:process_array_block, node) }.to output(/DEBUG/).to_stdout
      end
    end

    context 'when RAILS_OPENAPI_DEBUG is not set' do
      before do
        allow(ENV).to receive(:[]).with('RAILS_OPENAPI_DEBUG').and_return(nil)
      end

      it 'does not output debug information' do
        expect { processor.send(:process_array_block, node) }.not_to output.to_stdout
      end
    end
  end

  describe 'integration with call detectors' do
    it 'uses ArrayCallDetector for array method detection' do
      node = double('node', children: [nil, :array!, []])

      expect(described_class::CallDetectors::ArrayCallDetector).to receive(:array_call?).with(nil, :array!)
      allow(described_class::CallDetectors::ArrayCallDetector).to receive(:has_partial_key?).and_return(false)
      allow(processor).to receive(:process_array_property)
      allow(node).to receive(:updated).and_return(node)

      processor.on_send(node)
    end

    it 'uses JsonCallDetector for property detection in blocks' do
      send_node = double('send_node', children: [nil, :tags])
      args_node = double('args_node', type: :args, children: [:tag])
      body_node = double('body')
      node = double('node', children: [send_node, args_node, body_node])

      allow(described_class::CallDetectors::ArrayCallDetector).to receive(:array_call?).and_return(false)
      expect(described_class::CallDetectors::JsonCallDetector).to receive(:json_property?).with(nil,
                                                                                                :tags).and_return(true)
      expect(processor).to receive(:process_array_iteration_block).with(node, 'tags')

      processor.on_block(node)
    end
  end
end
