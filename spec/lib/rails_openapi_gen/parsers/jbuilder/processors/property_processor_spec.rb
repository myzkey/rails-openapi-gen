# frozen_string_literal: true

require 'spec_helper'

# Mock definitions are handled by spec/support/parser_ast_mocks.rb

RSpec.describe RailsOpenapiGen::Parsers::Jbuilder::Processors::PropertyProcessor do
  let(:file_path) { '/test/app/views/users/index.json.jbuilder' }
  let(:property_parser) { double('PropertyCommentParser') }
  let(:processor) { described_class.new(file_path, property_parser) }

  before do
    allow(property_parser).to receive(:find_property_comment_for_line).and_return(nil)

    # Mock required classes
    stub_const('RailsOpenapiGen::AstNodes::CommentData', double)
    stub_const('RailsOpenapiGen::AstNodes::PropertyNodeFactory', double)
    allow(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).and_return(double('CommentData'))
    allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_simple).and_return(double('SimplePropertyNode'))
  end

  describe '#on_send' do
    let(:receiver) { nil }
    let(:args) { [] }
    let(:node) { double('node', children: [receiver, method_name, *args]) }

    context 'with json property call' do
      let(:method_name) { :name }

      before do
        allow(described_class::CallDetectors::JsonCallDetector).to receive(:json_property?).with(receiver,
                                                                                                 method_name).and_return(true)
        allow(processor).to receive(:process_json_property)
      end

      it 'processes json property' do
        expect(processor).to receive(:process_json_property).with(node, 'name', args)
        processor.on_send(node)
      end
    end

    context 'with non-json property call' do
      let(:method_name) { :some_method }

      before do
        allow(described_class::CallDetectors::JsonCallDetector).to receive(:json_property?).with(receiver,
                                                                                                 method_name).and_return(false)
        # Mock the node to handle Parser::AST::Processor behavior
        allow(node).to receive(:updated).and_return(node)
      end

      it 'calls super without processing json logic' do
        expect(processor).not_to receive(:process_json_property)
        # The parent class (Parser::AST::Processor) will handle the node
        processor.on_send(node)
      end
    end
  end

  describe '#process_json_property' do
    let(:node) { double('node', location: double(line: 10)) }
    let(:property_name) { 'email' }
    let(:args) { [] }

    before do
      allow(processor).to receive(:find_comment_for_node).with(node).and_return(nil)
      allow(processor).to receive(:process_simple_property)
    end

    context 'when inside array block' do
      before do
        allow(processor).to receive(:inside_block?).with(:array).and_return(true)
      end

      it 'processes as simple property' do
        expect(processor).to receive(:process_simple_property).with(node, property_name, nil)
        processor.send(:process_json_property, node, property_name, args)
      end
    end

    context 'when not inside array block' do
      before do
        allow(processor).to receive(:inside_block?).with(:array).and_return(false)
      end

      it 'processes as simple property' do
        expect(processor).to receive(:process_simple_property).with(node, property_name, nil)
        processor.send(:process_json_property, node, property_name, args)
      end
    end

    context 'with comment data' do
      let(:comment_data) { { type: 'string', description: 'User email' } }

      before do
        allow(processor).to receive(:find_comment_for_node).with(node).and_return(comment_data)
        allow(processor).to receive(:inside_block?).with(:array).and_return(false)
      end

      it 'passes comment data to simple property processor' do
        expect(processor).to receive(:process_simple_property).with(node, property_name, comment_data)
        processor.send(:process_json_property, node, property_name, args)
      end
    end
  end

  describe '#process_simple_property' do
    let(:node) { double('node') }
    let(:property_name) { 'username' }

    before do
      allow(processor).to receive(:add_property)
    end

    context 'with complete comment data' do
      let(:comment_data) do
        {
          type: 'string',
          description: 'User username',
          required: true,
          enum: %w[admin user],
          field_name: 'username'
        }
      end

      it 'creates comment data with all attributes' do
        expect(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).with(
          type: 'string',
          description: 'User username',
          required: true,
          enum: %w[admin user],
          field_name: 'username'
        )

        processor.send(:process_simple_property, node, property_name, comment_data)
      end

      it 'creates simple property node with comment data' do
        comment_obj = double('CommentData')
        allow(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).and_return(comment_obj)

        expect(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_simple).with(
          property: property_name,
          comment_data: comment_obj
        )

        processor.send(:process_simple_property, node, property_name, comment_data)
      end

      it 'adds property to processor' do
        property_node = double('PropertyNode')
        allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_simple).and_return(property_node)

        expect(processor).to receive(:add_property).with(property_node)
        processor.send(:process_simple_property, node, property_name, comment_data)
      end
    end

    context 'with minimal comment data' do
      let(:comment_data) { { type: 'integer' } }

      it 'creates comment data with only provided attributes' do
        expect(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).with(
          type: 'integer',
          description: nil,
          required: nil,
          enum: nil,
          field_name: nil
        )

        processor.send(:process_simple_property, node, property_name, comment_data)
      end
    end

    context 'with empty comment data' do
      let(:comment_data) { {} }

      it 'creates TODO comment data' do
        expect(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).with(
          type: 'TODO: MISSING COMMENT'
        )

        processor.send(:process_simple_property, node, property_name, comment_data)
      end
    end

    context 'with nil comment data' do
      let(:comment_data) { nil }

      it 'creates TODO comment data' do
        expect(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).with(
          type: 'TODO: MISSING COMMENT'
        )

        processor.send(:process_simple_property, node, property_name, comment_data)
      end
    end

    context 'with comment data containing nil values' do
      let(:comment_data) do
        {
          type: 'string',
          description: nil,
          required: nil,
          enum: nil,
          field_name: nil
        }
      end

      it 'passes nil values to comment data constructor' do
        expect(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).with(
          type: 'string',
          description: nil,
          required: nil,
          enum: nil,
          field_name: nil
        )

        processor.send(:process_simple_property, node, property_name, comment_data)
      end
    end
  end

  describe 'integration with call detectors' do
    it 'uses JsonCallDetector for property detection' do
      node = double('node', children: [nil, :email])

      expect(described_class::CallDetectors::JsonCallDetector).to receive(:json_property?).with(nil, :email)
      allow(processor).to receive(:process_json_property)
      # Mock the node to handle Parser::AST::Processor behavior when json_property? returns false
      allow(node).to receive(:updated).and_return(node)

      processor.on_send(node)
    end
  end

  describe 'integration with base processor' do
    it 'inherits block stack management from base processor' do
      node = double('node', location: double(line: 5))
      property_name = 'test_property'

      # Simulate being inside an array block
      processor.send(:push_block, :array)

      allow(processor).to receive(:find_comment_for_node).and_return(nil)

      # Verify that the processor can still access block state from base processor
      expect(processor.send(:inside_block?, :array)).to be true
      allow(processor).to receive(:add_property)

      processor.send(:process_json_property, node, property_name, [])
    end
  end

  describe 'property creation scenarios' do
    let(:node) { double('node') }

    context 'creating string property' do
      let(:comment_data) { { type: 'string', description: 'A text field' } }

      it 'creates string property with description' do
        comment_obj = double('CommentData')
        property_node = double('PropertyNode')

        expect(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).with(
          type: 'string',
          description: 'A text field',
          required: nil,
          enum: nil,
          field_name: nil
        ).and_return(comment_obj)

        expect(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_simple).with(
          property: 'name',
          comment_data: comment_obj
        ).and_return(property_node)

        expect(processor).to receive(:add_property).with(property_node)

        processor.send(:process_simple_property, node, 'name', comment_data)
      end
    end

    context 'creating enum property' do
      let(:comment_data) do
        {
          type: 'string',
          enum: %w[active inactive pending],
          description: 'User status'
        }
      end

      it 'creates enum property' do
        expect(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).with(
          type: 'string',
          description: 'User status',
          required: nil,
          enum: %w[active inactive pending],
          field_name: nil
        )

        processor.send(:process_simple_property, node, 'status', comment_data)
      end
    end

    context 'creating required property' do
      let(:comment_data) { { type: 'integer', required: true, description: 'User ID' } }

      it 'creates required property' do
        expect(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).with(
          type: 'integer',
          description: 'User ID',
          required: true,
          enum: nil,
          field_name: nil
        )

        processor.send(:process_simple_property, node, 'id', comment_data)
      end
    end

    context 'creating property with field name mapping' do
      let(:comment_data) do
        {
          type: 'string',
          field_name: 'email_address',
          description: 'Email field'
        }
      end

      it 'creates property with field name' do
        expect(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).with(
          type: 'string',
          description: 'Email field',
          required: nil,
          enum: nil,
          field_name: 'email_address'
        )

        processor.send(:process_simple_property, node, 'email', comment_data)
      end
    end
  end

  describe 'error handling' do
    let(:node) { double('node') }
    let(:property_name) { 'test_prop' }

    context 'when CommentData creation fails' do
      before do
        allow(RailsOpenapiGen::AstNodes::CommentData).to receive(:new).and_raise(StandardError,
                                                                                 'Comment creation failed')
      end

      it 'propagates the error' do
        expect do
          processor.send(:process_simple_property, node, property_name, { type: 'string' })
        end.to raise_error(StandardError, 'Comment creation failed')
      end
    end

    context 'when PropertyNodeFactory creation fails' do
      before do
        allow(RailsOpenapiGen::AstNodes::PropertyNodeFactory).to receive(:create_simple).and_raise(StandardError,
                                                                                                   'Property creation failed')
      end

      it 'propagates the error' do
        expect do
          processor.send(:process_simple_property, node, property_name, { type: 'string' })
        end.to raise_error(StandardError, 'Property creation failed')
      end
    end
  end

  describe 'method argument handling' do
    context 'with no arguments' do
      let(:node) { double('node', children: [nil, :email]) }

      before do
        allow(described_class::CallDetectors::JsonCallDetector).to receive(:json_property?).and_return(true)
        allow(processor).to receive(:process_simple_property)
      end

      it 'passes empty args array' do
        expect(processor).to receive(:process_json_property).with(node, 'email', [])
        processor.on_send(node)
      end
    end

    context 'with single argument' do
      let(:arg) { double('arg') }
      let(:node) { double('node', children: [nil, :email, arg]) }

      before do
        allow(described_class::CallDetectors::JsonCallDetector).to receive(:json_property?).and_return(true)
        allow(processor).to receive(:process_simple_property)
      end

      it 'passes args array with one element' do
        expect(processor).to receive(:process_json_property).with(node, 'email', [arg])
        processor.on_send(node)
      end
    end

    context 'with multiple arguments' do
      let(:arg1) { double('arg1') }
      let(:arg2) { double('arg2') }
      let(:node) { double('node', children: [nil, :email, arg1, arg2]) }

      before do
        allow(described_class::CallDetectors::JsonCallDetector).to receive(:json_property?).and_return(true)
        allow(processor).to receive(:process_simple_property)
      end

      it 'passes all arguments' do
        expect(processor).to receive(:process_json_property).with(node, 'email', [arg1, arg2])
        processor.on_send(node)
      end
    end
  end
end
