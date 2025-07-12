# frozen_string_literal: true

require 'spec_helper'
require 'support/parser_ast_mocks'

RSpec.describe RailsOpenapiGen::Parsers::Jbuilder::Processors::CompositeProcessor do
  let(:file_path) { '/test/app/views/users/index.json.jbuilder' }
  let(:property_parser) { double('PropertyCommentParser') }
  let(:processor) { described_class.new(file_path, property_parser) }

  # Mock sub-processors
  let(:array_processor) { double('ArrayProcessor', properties: [], partials: []) }
  let(:object_processor) { double('ObjectProcessor', properties: [], partials: []) }
  let(:property_processor) { double('PropertyProcessor', properties: [], partials: []) }
  let(:partial_processor) { double('PartialProcessor', properties: [], partials: []) }

  before do
    # Mock the sub-processor initialization - access them from the module, not as nested classes
    allow(RailsOpenapiGen::Parsers::Jbuilder::Processors::ArrayProcessor).to receive(:new).and_return(array_processor)
    allow(RailsOpenapiGen::Parsers::Jbuilder::Processors::ObjectProcessor).to receive(:new).and_return(object_processor)
    allow(RailsOpenapiGen::Parsers::Jbuilder::Processors::PropertyProcessor).to receive(:new).and_return(property_processor)
    allow(RailsOpenapiGen::Parsers::Jbuilder::Processors::PartialProcessor).to receive(:new).and_return(partial_processor)

    # Mock clear_results method for all processors
    [array_processor, object_processor, property_processor, partial_processor].each do |mock_processor|
      allow(mock_processor).to receive(:send).with(:clear_results)
    end
  end

  describe '#initialize' do
    it 'calls super with file_path and property_parser' do
      expect_any_instance_of(described_class).to receive(:initialize).and_call_original
      described_class.new(file_path, property_parser)
    end

    it 'initializes all sub-processors' do
      expect(RailsOpenapiGen::Parsers::Jbuilder::Processors::ArrayProcessor).to receive(:new).with(file_path, property_parser)
      expect(RailsOpenapiGen::Parsers::Jbuilder::Processors::ObjectProcessor).to receive(:new).with(file_path, property_parser)
      expect(RailsOpenapiGen::Parsers::Jbuilder::Processors::PropertyProcessor).to receive(:new).with(file_path, property_parser)
      expect(RailsOpenapiGen::Parsers::Jbuilder::Processors::PartialProcessor).to receive(:new).with(file_path, property_parser)

      described_class.new(file_path, property_parser)
    end
  end

  describe '#on_send' do
    let(:node) { double('node', children: [receiver, method_name, *args]) }
    
    before do
      allow(node).to receive(:updated).and_return(node)
    end
    let(:receiver) { double('receiver') }
    let(:args) { [] }

    context 'with cache call' do
      let(:method_name) { :cache! }

      before do
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_call?).with(receiver, method_name).and_return(true)
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_if_call?).and_return(false)
        allow(processor).to receive(:process_children)
      end

      it 'calls super and skips processing' do
        # Verify that no specific processors are called
        expect(array_processor).not_to receive(:on_send)
        expect(object_processor).not_to receive(:on_send)
        expect(property_processor).not_to receive(:on_send)
        expect(partial_processor).not_to receive(:on_send)
        
        expect { processor.on_send(node) }.not_to raise_error
      end
    end

    context 'with cache_if call' do
      let(:method_name) { :cache_if! }

      before do
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_call?).and_return(false)
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_if_call?).with(receiver, method_name).and_return(true)
        allow(processor).to receive(:process_children)
      end

      it 'calls super and skips processing' do
        # Verify that no specific processors are called
        expect(array_processor).not_to receive(:on_send)
        expect(object_processor).not_to receive(:on_send)
        expect(property_processor).not_to receive(:on_send)
        expect(partial_processor).not_to receive(:on_send)
        
        expect { processor.on_send(node) }.not_to raise_error
      end
    end

    context 'with key format call' do
      let(:method_name) { :key_format! }

      before do
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_call?).and_return(false)
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_if_call?).and_return(false)
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::KeyFormatDetector).to receive(:key_format?).with(receiver, method_name).and_return(true)
        allow(processor).to receive(:process_children)
      end

      it 'calls super and skips processing' do
        # Verify that no specific processors are called
        expect(array_processor).not_to receive(:on_send)
        expect(object_processor).not_to receive(:on_send)
        expect(property_processor).not_to receive(:on_send)
        expect(partial_processor).not_to receive(:on_send)
        
        expect { processor.on_send(node) }.not_to raise_error
      end
    end

    context 'with null handling call' do
      let(:method_name) { :null! }

      before do
        stub_all_detectors_false_except(:null_handling?, true)
        allow(processor).to receive(:process_children)
      end

      it 'calls super and skips processing' do
        # Verify that no specific processors are called
        expect(array_processor).not_to receive(:on_send)
        expect(object_processor).not_to receive(:on_send)
        expect(property_processor).not_to receive(:on_send)
        expect(partial_processor).not_to receive(:on_send)
        
        expect { processor.on_send(node) }.not_to raise_error
      end
    end

    context 'with object manipulation call' do
      let(:method_name) { :merge! }

      before do
        stub_all_detectors_false_except(:object_manipulation?, true)
        allow(processor).to receive(:process_children)
      end

      it 'calls super and skips processing' do
        # Verify that no specific processors are called
        expect(array_processor).not_to receive(:on_send)
        expect(object_processor).not_to receive(:on_send)
        expect(property_processor).not_to receive(:on_send)
        expect(partial_processor).not_to receive(:on_send)
        
        expect { processor.on_send(node) }.not_to raise_error
      end
    end

    context 'with array call' do
      let(:method_name) { :array! }

      before do
        stub_all_detectors_false_except(:array_call?, true)
        allow(array_processor).to receive(:on_send)
      end

      it 'delegates to array processor and merges results' do
        expect(array_processor).to receive(:on_send).with(node)
        expect(processor).to receive(:merge_processor_results).with(array_processor)
        processor.on_send(node)
      end
    end

    context 'with partial call' do
      let(:method_name) { :partial! }

      before do
        stub_all_detectors_false_except(:partial_call?, true)
        allow(partial_processor).to receive(:on_send)
      end

      it 'delegates to partial processor and merges results' do
        expect(partial_processor).to receive(:on_send).with(node)
        expect(processor).to receive(:merge_processor_results).with(partial_processor)
        processor.on_send(node)
      end
    end

    context 'with json property call' do
      let(:method_name) { :name }

      before do
        stub_all_detectors_false_except(:json_property?, true)
        allow(property_processor).to receive(:on_send)
      end

      it 'delegates to property processor and merges results' do
        expect(property_processor).to receive(:on_send).with(node)
        expect(processor).to receive(:merge_processor_results).with(property_processor)
        processor.on_send(node)
      end
    end

    context 'with unknown method call' do
      let(:method_name) { :unknown_method }

      before do
        stub_all_detectors_false
      end

      it 'does not process anything' do
        expect(array_processor).not_to receive(:on_send)
        expect(object_processor).not_to receive(:on_send)
        expect(property_processor).not_to receive(:on_send)
        expect(partial_processor).not_to receive(:on_send)
        
        processor.on_send(node)
      end
    end
  end

  describe '#on_block' do
    let(:send_node) { double('send_node', children: [receiver, method_name]) }
    let(:args_node) { double('args_node') }
    let(:body) { double('body') }
    let(:node) { double('node', children: [send_node, args_node, body]) }
    let(:receiver) { double('receiver') }
    
    before do
      allow(node).to receive(:updated).and_return(node)
      allow(send_node).to receive(:updated).and_return(send_node)
      allow(args_node).to receive(:updated).and_return(args_node)
      allow(body).to receive(:updated).and_return(body)
    end

    context 'with cache block' do
      let(:method_name) { :cache! }

      before do
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_call?).with(receiver, method_name).and_return(true)
        allow(processor).to receive(:process)
      end

      it 'processes the block body directly' do
        expect(processor).to receive(:process).with(body)
        processor.on_block(node)
      end
    end

    context 'with cache_if block' do
      let(:method_name) { :cache_if! }

      before do
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_call?).and_return(false)
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_if_call?).with(receiver, method_name).and_return(true)
        allow(processor).to receive(:process)
      end

      it 'processes the block body directly' do
        expect(processor).to receive(:process).with(body)
        processor.on_block(node)
      end
    end

    context 'with json property block having arguments (array iteration)' do
      let(:method_name) { :tags }
      let(:args_node) { double('args_node', type: :args, children: [:tag]) }

      before do
        stub_cache_detectors_false
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).with(receiver, method_name).and_return(true)
        allow(array_processor).to receive(:on_block)
      end

      it 'delegates to array processor' do
        expect(array_processor).to receive(:on_block).with(node)
        expect(processor).to receive(:merge_processor_results).with(array_processor)
        processor.on_block(node)
      end
    end

    context 'with json property block without arguments (nested object)' do
      let(:method_name) { :profile }
      let(:args_node) { double('args_node', type: :args, children: []) }

      before do
        stub_cache_detectors_false
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).with(receiver, method_name).and_return(true)
        allow(object_processor).to receive(:on_block)
      end

      it 'delegates to object processor' do
        expect(object_processor).to receive(:on_block).with(node)
        expect(processor).to receive(:merge_processor_results).with(object_processor)
        processor.on_block(node)
      end
    end

    context 'with json property block with nil args_node' do
      let(:method_name) { :profile }
      let(:args_node) { nil }

      before do
        stub_cache_detectors_false
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).with(receiver, method_name).and_return(true)
        allow(object_processor).to receive(:on_block)
      end

      it 'delegates to object processor' do
        expect(object_processor).to receive(:on_block).with(node)
        expect(processor).to receive(:merge_processor_results).with(object_processor)
        processor.on_block(node)
      end
    end

    context 'with array! block' do
      let(:method_name) { :array! }

      before do
        stub_cache_detectors_false
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).and_return(false)
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::ArrayCallDetector).to receive(:array_call?).with(receiver, method_name).and_return(true)
        allow(array_processor).to receive(:on_block)
      end

      it 'delegates to array processor' do
        expect(array_processor).to receive(:on_block).with(node)
        expect(processor).to receive(:merge_processor_results).with(array_processor)
        processor.on_block(node)
      end
    end

    context 'with unknown block' do
      let(:method_name) { :unknown }

      before do
        stub_cache_detectors_false
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).and_return(false)
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::ArrayCallDetector).to receive(:array_call?).and_return(false)
        allow(processor).to receive(:process_children)
      end

      it 'calls super' do
        # Verify that no specific processors are called
        expect(array_processor).not_to receive(:on_block)
        expect(object_processor).not_to receive(:on_block)
        
        # Mock the super call to avoid AST processing issues
        allow_any_instance_of(RailsOpenapiGen::Parsers::Jbuilder::Processors::BaseProcessor).to receive(:on_block).and_return(node)
        
        result = processor.on_block(node)
        expect(result).to eq(node)
      end
    end
  end

  describe '#merge_processor_results' do
    let(:mock_processor) do
      double('MockProcessor', 
             properties: [{ name: 'test_prop' }], 
             partials: [{ name: 'test_partial' }])
    end

    before do
      allow(mock_processor).to receive(:send).with(:clear_results)
    end

    it 'merges properties from sub-processor' do
      processor.send(:merge_processor_results, mock_processor)
      expect(processor.properties).to include({ name: 'test_prop' })
    end

    it 'merges partials from sub-processor' do
      processor.send(:merge_processor_results, mock_processor)
      expect(processor.partials).to include({ name: 'test_partial' })
    end

    it 'clears sub-processor results' do
      expect(mock_processor).to receive(:send).with(:clear_results)
      processor.send(:merge_processor_results, mock_processor)
    end

    context 'with multiple properties and partials' do
      let(:mock_processor) do
        double('MockProcessor',
               properties: [{ name: 'prop1' }, { name: 'prop2' }],
               partials: [{ name: 'partial1' }, { name: 'partial2' }])
      end

      it 'merges all properties and partials' do
        processor.send(:merge_processor_results, mock_processor)
        
        expect(processor.properties.size).to eq(2)
        expect(processor.partials.size).to eq(2)
        expect(processor.properties).to include({ name: 'prop1' }, { name: 'prop2' })
        expect(processor.partials).to include({ name: 'partial1' }, { name: 'partial2' })
      end
    end
  end

  describe 'integration scenarios' do
    context 'with mixed method calls' do
      it 'processes different types of calls correctly' do
        # Simulate processing multiple different calls
        node1 = double('node1', children: [nil, :cache!, []])
        node2 = double('node2', children: [nil, :name, []])
        node3 = double('node3', children: [nil, :array!, []])
        
        # Mock updated method for all nodes
        allow(node1).to receive(:updated).and_return(node1)
        allow(node2).to receive(:updated).and_return(node2)
        allow(node3).to receive(:updated).and_return(node3)

        stub_all_detectors_false
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_call?).with(nil, :cache!).and_return(true)
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).with(nil, :name).and_return(true)
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::ArrayCallDetector).to receive(:array_call?).with(nil, :array!).and_return(true)

        allow(processor).to receive(:process_children)
        allow(property_processor).to receive(:on_send)
        allow(array_processor).to receive(:on_send)

        processor.on_send(node1)  # Should call super
        processor.on_send(node2)  # Should delegate to property processor
        processor.on_send(node3)  # Should delegate to array processor

        expect(property_processor).to have_received(:on_send).with(node2)
        expect(array_processor).to have_received(:on_send).with(node3)
      end
    end

    context 'with nested block structures' do
      it 'handles nested object and array blocks' do
        # Object block
        object_send = double('object_send', children: [nil, :profile])
        object_args = double('object_args', type: :args, children: [])
        object_body = double('object_body')
        object_node = double('object_node', children: [object_send, object_args, object_body])

        # Array block
        array_send = double('array_send', children: [nil, :tags])
        array_args = double('array_args', type: :args, children: [:tag])
        array_body = double('array_body')
        array_node = double('array_node', children: [array_send, array_args, array_body])

        stub_cache_detectors_false
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).and_return(true)
        allow(object_processor).to receive(:on_block)
        allow(array_processor).to receive(:on_block)

        processor.on_block(object_node)
        processor.on_block(array_node)

        expect(object_processor).to have_received(:on_block).with(object_node)
        expect(array_processor).to have_received(:on_block).with(array_node)
      end
    end
  end

  describe 'call detector integration' do
    context 'with all detectors returning false' do
      before { stub_all_detectors_false }

      it 'does not delegate to any processor for unknown calls' do
        node = double('node', children: [nil, :unknown, []])
        
        expect(array_processor).not_to receive(:on_send)
        expect(object_processor).not_to receive(:on_send)
        expect(property_processor).not_to receive(:on_send)
        expect(partial_processor).not_to receive(:on_send)
        
        processor.on_send(node)
      end
    end

    context 'with multiple detectors returning true' do
      it 'follows detection priority order' do
        node = double('node', children: [nil, :test, []])
        allow(node).to receive(:updated).and_return(node)
        
        # Cache detector has highest priority
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_call?).and_return(true)
        allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).and_return(true)
        allow(processor).to receive(:process_children)
        allow(property_processor).to receive(:on_send)

        processor.on_send(node)
        
        # Should call super (cache behavior) not delegate to property processor
        expect(property_processor).not_to have_received(:on_send)
        # Verify that it follows cache priority over JSON property calls
      end
    end
  end

  # Helper methods
  def stub_all_detectors_false
    allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_call?).and_return(false)
    allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_if_call?).and_return(false)
    allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::KeyFormatDetector).to receive(:key_format?).and_return(false)
    allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::NullHandlingDetector).to receive(:null_handling?).and_return(false)
    allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::ObjectManipulationDetector).to receive(:object_manipulation?).and_return(false)
    allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::ArrayCallDetector).to receive(:array_call?).and_return(false)
    allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::PartialCallDetector).to receive(:partial_call?).and_return(false)
    allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).and_return(false)
  end

  def stub_all_detectors_false_except(detector_method, return_value)
    stub_all_detectors_false
    
    case detector_method
    when :null_handling?
      allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::NullHandlingDetector).to receive(:null_handling?).and_return(return_value)
    when :object_manipulation?
      allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::ObjectManipulationDetector).to receive(:object_manipulation?).and_return(return_value)
    when :array_call?
      allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::ArrayCallDetector).to receive(:array_call?).and_return(return_value)
    when :partial_call?
      allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::PartialCallDetector).to receive(:partial_call?).and_return(return_value)
    when :json_property?
      allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::JsonCallDetector).to receive(:json_property?).and_return(return_value)
    end
  end

  def stub_cache_detectors_false
    allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_call?).and_return(false)
    allow(RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::CacheCallDetector).to receive(:cache_if_call?).and_return(false)
  end
end