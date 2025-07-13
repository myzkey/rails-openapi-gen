# frozen_string_literal: true

require 'spec_helper'
require 'support/parser_ast_mocks'

RSpec.describe RailsOpenapiGen::Parsers::Jbuilder::Processors::BaseProcessor do
  let(:file_path) { '/test/app/views/users/index.json.jbuilder' }
  let(:property_parser) { double('PropertyCommentParser') }
  let(:processor) { described_class.new(file_path, property_parser) }

  describe '#initialize' do
    it 'sets file path and property parser' do
      expect(processor.instance_variable_get(:@file_path)).to eq(file_path)
      expect(processor.instance_variable_get(:@property_parser)).to eq(property_parser)
    end

    it 'initializes arrays and stacks' do
      expect(processor.properties).to eq([])
      expect(processor.partials).to eq([])
      expect(processor.instance_variable_get(:@block_stack)).to eq([])
      expect(processor.instance_variable_get(:@conditional_stack)).to eq([])
    end
  end

  describe '#properties' do
    it 'returns properties array' do
      expect(processor.properties).to be_an(Array)
    end

    it 'is always initialized even if nil' do
      processor.instance_variable_set(:@properties, nil)
      expect(processor.properties).to eq([])
    end
  end

  describe '#partials' do
    it 'returns partials array' do
      expect(processor.partials).to be_an(Array)
    end

    it 'is always initialized even if nil' do
      processor.instance_variable_set(:@partials, nil)
      expect(processor.partials).to eq([])
    end
  end

  describe '#on_send' do
    let(:node) { double('node', type: :send, children: [nil, :method_name], updated: nil) }

    it 'calls super to process node' do
      allow(node).to receive(:updated).and_return(node)
      processor.on_send(node)
    end
  end

  describe '#on_block' do
    let(:send_node) { double('send_node', type: :send, children: [nil, :method_name]) }
    let(:args_node) { double('args_node', type: :args, children: []) }
    let(:body_node) { double('body_node', type: :begin, children: []) }
    let(:children) { [send_node, args_node, body_node] }
    let(:node) { double('node', type: :block, children: children) }

    it 'calls super to process node' do
      # Instead of mocking individual process calls, just expect that super is called
      expect_any_instance_of(Parser::AST::Processor).to receive(:on_block).with(node)
      processor.on_block(node)
    end
  end

  describe '#on_if' do
    let(:condition_node) { double('condition', type: :send) }
    let(:body_node) { double('body', type: :begin, children: []) }
    let(:node) { double('node', type: :if, location: double(line: 10), children: [condition_node, body_node, nil]) }

    context 'when if statement has conditional comment' do
      before do
        allow(processor).to receive(:find_comment_for_node).with(node).and_return({ conditional: true })
      end

      it 'pushes and pops conditional stack' do
        expect(processor.instance_variable_get(:@conditional_stack)).to be_empty

        # Mock the super call to avoid AST processing issues
        expect_any_instance_of(Parser::AST::Processor).to receive(:on_if).with(node)

        processor.on_if(node)

        # After processing, stack should be empty again
        expect(processor.instance_variable_get(:@conditional_stack)).to be_empty
      end
    end

    context 'when if statement has no conditional comment' do
      before do
        allow(processor).to receive(:find_comment_for_node).with(node).and_return(nil)
      end

      it 'does not modify conditional stack' do
        # Mock the super call to avoid AST processing issues
        expect_any_instance_of(Parser::AST::Processor).to receive(:on_if).with(node)

        processor.on_if(node)
        expect(processor.instance_variable_get(:@conditional_stack)).to be_empty
      end
    end
  end

  describe '#on_begin' do
    let(:child1) { double('child1', type: :send) }
    let(:child2) { double('child2', type: :send) }
    let(:node) { double('node', type: :begin, children: [child1, child2]) }

    it 'calls super to process children' do
      # Mock the super call to avoid AST processing issues
      expect_any_instance_of(Parser::AST::Processor).to receive(:on_begin).with(node)
      processor.on_begin(node)
    end
  end

  describe '#handler_missing' do
    let(:node) { double('node') }

    it 'returns the node' do
      result = processor.handler_missing(node)
      expect(result).to eq(node)
    end
  end

  describe '#find_comment_for_node' do
    let(:node) { double('node', location: double(line: 15)) }
    let(:comment_data) { { type: 'string', description: 'Test property' } }

    it 'finds comment for node line number' do
      expect(property_parser).to receive(:find_property_comment_for_line).with(15).and_return(comment_data)

      result = processor.send(:find_comment_for_node, node)
      expect(result).to eq(comment_data)
    end
  end

  describe '#resolve_partial_path' do
    context 'with simple partial name' do
      it 'adds underscore prefix and extension' do
        result = processor.send(:resolve_partial_path, 'user')
        expect(result).to eq('/test/app/views/users/_user.json.jbuilder')
      end

      it 'does not double underscore if already present' do
        result = processor.send(:resolve_partial_path, '_user')
        expect(result).to eq('/test/app/views/users/_user.json.jbuilder')
      end
    end

    context 'with nested partial name' do
      it 'resolves nested partial path correctly' do
        result = processor.send(:resolve_partial_path, 'shared/user')
        expected = '/test/app/views/shared/_user.json.jbuilder'
        expect(result).to eq(expected)
      end

      it 'handles deep nesting' do
        result = processor.send(:resolve_partial_path, 'api/v1/user_detail')
        expected = '/test/app/views/api/v1/_user_detail.json.jbuilder'
        expect(result).to eq(expected)
      end
    end

    context 'with absolute partial path from views directory' do
      let(:file_path) { '/test/app/views/api/users/show.json.jbuilder' }

      it 'resolves from views root' do
        result = processor.send(:resolve_partial_path, 'shared/user')
        expected = '/test/app/views/shared/_user.json.jbuilder'
        expect(result).to eq(expected)
      end
    end

    context 'with nil inputs' do
      it 'returns nil for nil partial name' do
        result = processor.send(:resolve_partial_path, nil)
        expect(result).to be_nil
      end

      it 'returns nil for nil file path' do
        processor.instance_variable_set(:@file_path, nil)
        result = processor.send(:resolve_partial_path, 'user')
        expect(result).to be_nil
      end
    end
  end

  describe '#parse_partial_for_nested_object' do
    let(:partial_path) { '/test/app/views/users/_user.json.jbuilder' }
    let(:mock_parser) { double('JbuilderParser') }
    let(:property_node) { double('PropertyNode', property: 'name', type: 'string') }
    let(:parse_result) { double('ParseResult', children: [property_node]) }

    before do
      mock_class = double('JbuilderParserClass')
      stub_const('RailsOpenapiGen::Parsers::Jbuilder::Processors::BaseProcessor::JbuilderParser', mock_class)
      allow(mock_class).to receive(:new).with(partial_path).and_return(mock_parser)
      allow(mock_parser).to receive(:parse).and_return(parse_result)
      allow(parse_result).to receive(:respond_to?).with(:children).and_return(true)
    end

    it 'creates new parser and returns properties' do
      result = processor.send(:parse_partial_for_nested_object, partial_path)
      expect(result).to eq([property_node])
    end
  end

  describe '#add_property' do
    let(:property_node) { double('PropertyNode', class: 'PropertyNode') }

    context 'with PropertyNode' do
      it 'adds property node to properties array' do
        processor.send(:add_property, property_node)
        expect(processor.properties).to include(property_node)
      end
    end

    context 'with hash (backward compatibility)' do
      let(:property_hash) { { property: 'name', type: 'string' } }
      let(:converted_node) { double('ConvertedPropertyNode') }

      before do
        stub_const('RailsOpenapiGen::AstNodes::PropertyNodeFactory', double)
        allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:from_hash).with(property_hash).and_return(converted_node)
      end

      it 'converts hash to PropertyNode and adds it' do
        processor.send(:add_property, property_hash)
        expect(processor.properties).to include(converted_node)
      end
    end

    context 'when inside conditional block' do
      let(:conditional_node) { double('ConditionalPropertyNode') }

      before do
        processor.instance_variable_get(:@conditional_stack).push(true)
        allow(processor).to receive(:create_conditional_node).with(property_node).and_return(conditional_node)
      end

      it 'creates conditional version and adds it' do
        processor.send(:add_property, property_node)
        expect(processor.properties).to include(conditional_node)
      end
    end
  end

  describe '#create_conditional_node' do
    let(:comment_data) { double('CommentData') }

    context 'with SimplePropertyNode' do
      let(:simple_node) do
        double('SimplePropertyNode',
               property: 'name',
               comment_data: comment_data)
      end

      before do
        # Mock case statement class checking (uses ===)
        allow(RailsOpenapiGen::AstNodes::SimplePropertyNode).to receive(:===).with(simple_node).and_return(true)
        allow(RailsOpenapiGen::AstNodes::ArrayPropertyNode).to receive(:===).with(simple_node).and_return(false)
        allow(RailsOpenapiGen::AstNodes::ObjectPropertyNode).to receive(:===).with(simple_node).and_return(false)
        allow(RailsOpenapiGen::AstNodes::ArrayRootNode).to receive(:===).with(simple_node).and_return(false)

        stub_const('RailsOpenapiGen::AstNodes::PropertyNodeFactory', double)
        allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_simple).and_return(double('ConditionalSimpleNode'))
      end

      it 'creates conditional simple property node' do
        expect(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_simple).with(
          property: 'name',
          comment_data: comment_data,
          is_conditional: true
        )

        processor.send(:create_conditional_node, simple_node)
      end
    end

    context 'with ArrayPropertyNode' do
      let(:array_node) do
        double('ArrayPropertyNode',
               property: 'items',
               comment_data: comment_data,
               array_item_properties: [])
      end

      before do
        # Mock case statement class checking (uses ===)
        allow(RailsOpenapiGen::AstNodes::SimplePropertyNode).to receive(:===).with(array_node).and_return(false)
        allow(RailsOpenapiGen::AstNodes::ArrayPropertyNode).to receive(:===).with(array_node).and_return(true)
        allow(RailsOpenapiGen::AstNodes::ObjectPropertyNode).to receive(:===).with(array_node).and_return(false)
        allow(RailsOpenapiGen::AstNodes::ArrayRootNode).to receive(:===).with(array_node).and_return(false)

        stub_const('RailsOpenapiGen::AstNodes::PropertyNodeFactory', double)
        allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_array).and_return(double('ConditionalArrayNode'))
      end

      it 'creates conditional array property node' do
        expect(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_array).with(
          property: 'items',
          comment_data: comment_data,
          is_conditional: true,
          array_item_properties: []
        )

        processor.send(:create_conditional_node, array_node)
      end
    end

    context 'with ArrayRootNode' do
      let(:array_root_node) { double('ArrayRootNode', class: RailsOpenapiGen::AstNodes::ArrayRootNode) }

      it 'returns the node unchanged' do
        result = processor.send(:create_conditional_node, array_root_node)
        expect(result).to eq(array_root_node)
      end
    end
  end

  describe 'block stack management' do
    describe '#push_block' do
      it 'pushes block type to stack' do
        processor.send(:push_block, :array)
        expect(processor.instance_variable_get(:@block_stack)).to eq([:array])
      end

      it 'maintains order of nested blocks' do
        processor.send(:push_block, :object)
        processor.send(:push_block, :array)
        expect(processor.instance_variable_get(:@block_stack)).to eq(%i[object array])
      end
    end

    describe '#pop_block' do
      it 'pops and returns last block type' do
        processor.send(:push_block, :array)
        processor.send(:push_block, :object)

        result = processor.send(:pop_block)
        expect(result).to eq(:object)
        expect(processor.instance_variable_get(:@block_stack)).to eq([:array])
      end

      it 'returns nil when stack is empty' do
        result = processor.send(:pop_block)
        expect(result).to be_nil
      end
    end

    describe '#inside_block?' do
      it 'returns true when inside specified block type' do
        processor.send(:push_block, :array)
        expect(processor.send(:inside_block?, :array)).to be true
      end

      it 'returns false when not inside specified block type' do
        processor.send(:push_block, :object)
        expect(processor.send(:inside_block?, :array)).to be false
      end

      it 'returns false when stack is empty' do
        expect(processor.send(:inside_block?, :array)).to be false
      end

      it 'only checks the current (last) block type' do
        processor.send(:push_block, :object)
        processor.send(:push_block, :array)
        expect(processor.send(:inside_block?, :object)).to be false
        expect(processor.send(:inside_block?, :array)).to be true
      end
    end
  end

  describe '#process_node' do
    context 'with send node' do
      let(:node) { double('node', type: :send) }

      it 'calls on_send' do
        expect(processor).to receive(:on_send).with(node)
        processor.send(:process_node, node)
      end
    end

    context 'with block node' do
      let(:node) { double('node', type: :block) }

      it 'calls on_block' do
        expect(processor).to receive(:on_block).with(node)
        processor.send(:process_node, node)
      end
    end

    context 'with if node' do
      let(:node) { double('node', type: :if) }

      it 'calls on_if' do
        expect(processor).to receive(:on_if).with(node)
        processor.send(:process_node, node)
      end
    end

    context 'with other node types' do
      let(:child1) { double('child1', type: :send) }
      let(:child2) { double('child2', type: :str) }
      let(:node) { double('node', type: :other, children: [child1, child2]) }

      it 'recursively processes children that are AST nodes' do
        allow(child1).to receive(:is_a?).with(Parser::AST::Node).and_return(true)
        allow(child2).to receive(:is_a?).with(Parser::AST::Node).and_return(false)
        allow(processor).to receive(:process).with(child1).and_return(child1)
        processor.send(:process_node, node)
      end
    end

    context 'with nil node' do
      it 'returns early without processing' do
        expect(processor).not_to receive(:on_send)
        processor.send(:process_node, nil)
      end
    end
  end

  describe '#clear_results' do
    it 'clears properties and partials arrays' do
      processor.instance_variable_set(:@properties, %w[prop1 prop2])
      processor.instance_variable_set(:@partials, ['partial1'])

      processor.send(:clear_results)

      expect(processor.properties).to be_empty
      expect(processor.partials).to be_empty
    end
  end

  describe 'environment variable debug logging' do
    context 'when RAILS_OPENAPI_DEBUG is set' do
      before do
        allow(ENV).to receive(:[]).with('RAILS_OPENAPI_DEBUG').and_return('true')
      end

      it 'outputs debug information in resolve_partial_path' do
        expect { processor.send(:resolve_partial_path, 'user') }.to output(/DEBUG/).to_stdout
      end
    end

    context 'when RAILS_OPENAPI_DEBUG is not set' do
      before do
        allow(ENV).to receive(:[]).with('RAILS_OPENAPI_DEBUG').and_return(nil)
      end

      it 'does not output debug information' do
        expect { processor.send(:resolve_partial_path, 'user') }.not_to output.to_stdout
      end
    end
  end

  describe 'integration scenarios' do
    context 'with nested conditional blocks' do
      it 'properly manages conditional stack with nested conditions' do
        condition_node1 = double('condition1', type: :send)
        body_node1 = double('body1', type: :begin, children: [])
        node1 = double('node1', type: :if, location: double(line: 10), children: [condition_node1, body_node1, nil])

        condition_node2 = double('condition2', type: :send)
        body_node2 = double('body2', type: :begin, children: [])
        node2 = double('node2', type: :if, location: double(line: 20), children: [condition_node2, body_node2, nil])

        allow(processor).to receive(:find_comment_for_node).with(node1).and_return({ conditional: true })
        allow(processor).to receive(:find_comment_for_node).with(node2).and_return({ conditional: true })

        # Mock the super calls to avoid AST processing issues
        expect_any_instance_of(Parser::AST::Processor).to receive(:on_if).with(node1)
        expect_any_instance_of(Parser::AST::Processor).to receive(:on_if).with(node2)

        # Test proper nesting behavior - each call should push and pop
        expect(processor.instance_variable_get(:@conditional_stack)).to be_empty
        processor.on_if(node1)
        expect(processor.instance_variable_get(:@conditional_stack)).to be_empty

        processor.on_if(node2)
        expect(processor.instance_variable_get(:@conditional_stack)).to be_empty
      end
    end

    context 'with complex block nesting' do
      it 'manages multiple block types correctly' do
        processor.send(:push_block, :root)
        processor.send(:push_block, :object)
        processor.send(:push_block, :array)

        expect(processor.send(:inside_block?, :array)).to be true
        expect(processor.send(:inside_block?, :object)).to be false

        processor.send(:pop_block)
        expect(processor.send(:inside_block?, :object)).to be true

        processor.send(:pop_block)
        expect(processor.send(:inside_block?, :root)).to be true
      end
    end
  end
end
