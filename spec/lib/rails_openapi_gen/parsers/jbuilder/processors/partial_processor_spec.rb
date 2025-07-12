# frozen_string_literal: true

require 'spec_helper'

# Mock Parser dependencies before requiring the processor
module Parser
  module AST
    class Processor
      def initialize; end
      def process(node); end
      def process_children(node); end
    end
    
    class Node
      attr_reader :type, :children, :location
      
      def initialize(type, children = [], location = nil)
        @type = type
        @children = children
        @location = location || double('location', line: 1)
      end
      
      # Add updated method for Parser 3.1.3 compatibility
      def updated(new_type = nil, new_children = nil, new_properties = {})
        self.class.new(new_type || @type, new_children || @children, @location)
      end
    end
  end
end

RSpec.describe RailsOpenapiGen::Parsers::Jbuilder::Processors::PartialProcessor do
  let(:file_path) { '/test/app/views/users/index.json.jbuilder' }
  let(:property_parser) { double('PropertyCommentParser') }
  let(:processor) { described_class.new(file_path, property_parser) }

  before do
    allow(property_parser).to receive(:find_property_comment_for_line).and_return(nil)
  end

  describe '#on_send' do
    let(:receiver) { nil }
    let(:args) { [] }
    let(:node) { 
      double('node', 
        children: [receiver, method_name, *args],
        updated: double('updated_node')
      ) 
    }

    context 'with partial call' do
      let(:method_name) { :partial! }

      before do
        # Mock the call detector method through the local alias used in the processor
        allow(described_class::CallDetectors::PartialCallDetector).to receive(:partial_call?).with(receiver, method_name).and_return(true)
        allow(processor).to receive(:process_partial)
        # Allow the Parser gem's processor to be called
        allow_any_instance_of(Parser::AST::Processor).to receive(:on_send)
      end

      it 'processes partial with args' do
        expect(processor).to receive(:process_partial).with(args)
        processor.on_send(node)
      end

      it 'calls super to continue processing' do
        expect_any_instance_of(Parser::AST::Processor).to receive(:on_send).with(node)
        processor.on_send(node)
      end
    end

    context 'with non-partial call' do
      let(:method_name) { :name }

      before do
        # Mock the call detector to return false for non-partial calls
        allow(described_class::CallDetectors::PartialCallDetector).to receive(:partial_call?).with(receiver, method_name).and_return(false)
        # Allow the Parser gem's processor to be called
        allow_any_instance_of(Parser::AST::Processor).to receive(:on_send)
      end

      it 'does not process as partial' do
        expect(processor).not_to receive(:process_partial)
        expect_any_instance_of(Parser::AST::Processor).to receive(:on_send).with(node)
        processor.on_send(node)
      end
    end
  end

  describe '#process_partial' do
    context 'with empty args' do
      it 'returns early without processing' do
        expect(processor).not_to receive(:extract_partial_name)
        processor.send(:process_partial, [])
      end
    end

    context 'with valid partial name' do
      let(:args) { [double('arg')] }
      let(:partial_name) { 'users/user' }
      let(:resolved_path) { '/test/app/views/users/_user.json.jbuilder' }

      before do
        allow(processor).to receive(:extract_partial_name).with(args).and_return(partial_name)
        allow(processor).to receive(:resolve_partial_path).with(partial_name).and_return(resolved_path)
      end

      it 'extracts partial name and resolves path' do
        expect(processor).to receive(:extract_partial_name).with(args)
        expect(processor).to receive(:resolve_partial_path).with(partial_name)
        
        processor.send(:process_partial, args)
      end

      it 'adds resolved path to partials collection' do
        processor.send(:process_partial, args)
        expect(processor.partials).to include(resolved_path)
      end

      context 'when partial name cannot be extracted' do
        before do
          allow(processor).to receive(:extract_partial_name).with(args).and_return(nil)
        end

        it 'does not add anything to partials' do
          processor.send(:process_partial, args)
          expect(processor.partials).to be_empty
        end
      end

      context 'when partial path cannot be resolved' do
        before do
          allow(processor).to receive(:resolve_partial_path).with(partial_name).and_return(nil)
        end

        it 'does not add anything to partials' do
          processor.send(:process_partial, args)
          expect(processor.partials).to be_empty
        end
      end
    end
  end

  describe '#extract_partial_name' do
    context 'with string argument' do
      let(:string_node) { double('string_node', type: :str, children: ['users/user']) }
      let(:args) { [string_node] }

      it 'extracts partial name from string node' do
        result = processor.send(:extract_partial_name, args)
        expect(result).to eq('users/user')
      end
    end

    context 'with hash argument containing partial key' do
      let(:partial_key) { double('partial_key', type: :sym, children: [:partial]) }
      let(:partial_value) { double('partial_value', type: :str, children: ['shared/user']) }
      let(:partial_pair) { double('partial_pair', type: :pair, children: [partial_key, partial_value]) }
      let(:hash_node) { double('hash_node', type: :hash, children: [partial_pair]) }
      let(:args) { [hash_node] }

      it 'extracts partial name from hash with partial key' do
        result = processor.send(:extract_partial_name, args)
        expect(result).to eq('shared/user')
      end
    end

    context 'with hash argument containing multiple keys' do
      let(:partial_key) { double('partial_key', type: :sym, children: [:partial]) }
      let(:partial_value) { double('partial_value', type: :str, children: ['api/user']) }
      let(:partial_pair) { double('partial_pair', type: :pair, children: [partial_key, partial_value]) }
      
      let(:locals_key) { double('locals_key', type: :sym, children: [:locals]) }
      let(:locals_value) { double('locals_value', type: :hash, children: []) }
      let(:locals_pair) { double('locals_pair', type: :pair, children: [locals_key, locals_value]) }
      
      let(:hash_node) { double('hash_node', type: :hash, children: [locals_pair, partial_pair]) }
      let(:args) { [hash_node] }

      it 'finds partial key among multiple hash keys' do
        result = processor.send(:extract_partial_name, args)
        expect(result).to eq('api/user')
      end
    end

    context 'with hash argument without partial key' do
      let(:other_key) { double('other_key', type: :sym, children: [:template]) }
      let(:other_value) { double('other_value', type: :str, children: ['some/template']) }
      let(:other_pair) { double('other_pair', type: :pair, children: [other_key, other_value]) }
      let(:hash_node) { double('hash_node', type: :hash, children: [other_pair]) }
      let(:args) { [hash_node] }

      it 'returns nil when partial key not found' do
        result = processor.send(:extract_partial_name, args)
        expect(result).to be_nil
      end
    end

    context 'with hash argument containing non-string partial value' do
      let(:partial_key) { double('partial_key', type: :sym, children: [:partial]) }
      let(:partial_value) { double('partial_value', type: :sym, children: [:symbol_value]) }
      let(:partial_pair) { double('partial_pair', type: :pair, children: [partial_key, partial_value]) }
      let(:hash_node) { double('hash_node', type: :hash, children: [partial_pair]) }
      let(:args) { [hash_node] }

      it 'returns nil when partial value is not a string' do
        result = processor.send(:extract_partial_name, args)
        expect(result).to be_nil
      end
    end

    context 'with hash argument containing non-symbol partial key' do
      let(:partial_key) { double('partial_key', type: :str, children: ['partial']) }
      let(:partial_value) { double('partial_value', type: :str, children: ['some/partial']) }
      let(:partial_pair) { double('partial_pair', type: :pair, children: [partial_key, partial_value]) }
      let(:hash_node) { double('hash_node', type: :hash, children: [partial_pair]) }
      let(:args) { [hash_node] }

      it 'returns nil when partial key is not a symbol' do
        result = processor.send(:extract_partial_name, args)
        expect(result).to be_nil
      end
    end

    context 'with non-pair hash children' do
      let(:non_pair_child) { double('non_pair', type: :send) }
      let(:hash_node) { double('hash_node', type: :hash, children: [non_pair_child]) }
      let(:args) { [hash_node] }

      it 'skips non-pair children and returns nil' do
        result = processor.send(:extract_partial_name, args)
        expect(result).to be_nil
      end
    end

    context 'with integer argument' do
      let(:integer_node) { double('integer_node', type: :int, children: [42]) }
      let(:args) { [integer_node] }

      it 'returns nil for non-string, non-hash arguments' do
        result = processor.send(:extract_partial_name, args)
        expect(result).to be_nil
      end
    end

    context 'with symbol argument' do
      let(:symbol_node) { double('symbol_node', type: :sym, children: [:symbol_name]) }
      let(:args) { [symbol_node] }

      it 'returns nil for symbol arguments' do
        result = processor.send(:extract_partial_name, args)
        expect(result).to be_nil
      end
    end

    context 'with empty hash' do
      let(:hash_node) { double('hash_node', type: :hash, children: []) }
      let(:args) { [hash_node] }

      it 'returns nil for empty hash' do
        result = processor.send(:extract_partial_name, args)
        expect(result).to be_nil
      end
    end
  end

  describe 'integration with call detectors' do
    it 'uses PartialCallDetector for partial detection' do
      node = double('node', 
        children: [nil, :partial!, []],
        updated: double('updated_node')
      )
      
      # Test that the detector method is called and that process_partial is called when it returns true
      expect(described_class::CallDetectors::PartialCallDetector).to receive(:partial_call?).with(nil, :partial!)
      allow(processor).to receive(:process_partial)
      allow_any_instance_of(Parser::AST::Processor).to receive(:on_send)
      
      processor.on_send(node)
    end
  end

  describe 'integration with base processor' do
    it 'inherits partial path resolution from base processor' do
      args = [double('string_node', type: :str, children: ['user'])]
      resolved_path = '/test/resolved/path/_user.json.jbuilder'
      
      expect(processor).to receive(:resolve_partial_path).with('user').and_return(resolved_path)
      
      processor.send(:process_partial, args)
      expect(processor.partials).to include(resolved_path)
    end
  end

  describe 'debug logging' do
    let(:args) { [double('string_node', type: :str, children: ['user'])] }
    let(:resolved_path) { '/test/path/_user.json.jbuilder' }

    before do
      allow(processor).to receive(:resolve_partial_path).with('user').and_return(resolved_path)
      allow(File).to receive(:exist?).with(resolved_path).and_return(true)
    end

    context 'when RAILS_OPENAPI_DEBUG is set' do
      before do
        allow(ENV).to receive(:[]).with('RAILS_OPENAPI_DEBUG').and_return('true')
      end

      it 'outputs debug information' do
        expect { processor.send(:process_partial, args) }.to output(/DEBUG/).to_stdout
      end

      it 'logs partial name and resolved path' do
        output = capture_stdout { processor.send(:process_partial, args) }
        expect(output).to match(/Found partial: user/)
        expect(output).to match(/Resolved partial path:/)
        expect(output).to match(/Partial exists: true/)
      end
    end

    context 'when RAILS_OPENAPI_DEBUG is not set' do
      before do
        allow(ENV).to receive(:[]).with('RAILS_OPENAPI_DEBUG').and_return(nil)
      end

      it 'does not output debug information' do
        expect { processor.send(:process_partial, args) }.not_to output.to_stdout
      end
    end

    def capture_stdout
      original_stdout = $stdout
      $stdout = StringIO.new
      yield
      $stdout.string
    ensure
      $stdout = original_stdout
    end
  end

  describe 'real-world usage patterns' do
    context 'with simple partial call' do
      let(:string_node) { double('string_node', type: :str, children: ['shared/header']) }
      let(:args) { [string_node] }

      before do
        allow(processor).to receive(:resolve_partial_path).with('shared/header').and_return('/test/views/shared/_header.json.jbuilder')
      end

      it 'handles simple string partial calls' do
        processor.send(:process_partial, args)
        expect(processor.partials).to include('/test/views/shared/_header.json.jbuilder')
      end
    end

    context 'with partial call with locals' do
      let(:partial_key) { double('partial_key', type: :sym, children: [:partial]) }
      let(:partial_value) { double('partial_value', type: :str, children: ['users/user_card']) }
      let(:partial_pair) { double('partial_pair', type: :pair, children: [partial_key, partial_value]) }
      
      let(:locals_key) { double('locals_key', type: :sym, children: [:locals]) }
      let(:locals_hash) { double('locals_hash', type: :hash, children: []) }
      let(:locals_pair) { double('locals_pair', type: :pair, children: [locals_key, locals_hash]) }
      
      let(:hash_node) { double('hash_node', type: :hash, children: [partial_pair, locals_pair]) }
      let(:args) { [hash_node] }

      before do
        allow(processor).to receive(:resolve_partial_path).with('users/user_card').and_return('/test/views/users/_user_card.json.jbuilder')
      end

      it 'handles partial calls with locals hash' do
        processor.send(:process_partial, args)
        expect(processor.partials).to include('/test/views/users/_user_card.json.jbuilder')
      end
    end

    context 'with nested directory partials' do
      let(:string_node) { double('string_node', type: :str, children: ['api/v1/users/profile']) }
      let(:args) { [string_node] }

      before do
        allow(processor).to receive(:resolve_partial_path).with('api/v1/users/profile').and_return('/test/views/api/v1/users/_profile.json.jbuilder')
      end

      it 'handles deeply nested partial paths' do
        processor.send(:process_partial, args)
        expect(processor.partials).to include('/test/views/api/v1/users/_profile.json.jbuilder')
      end
    end
  end

  describe 'error handling' do
    context 'when resolve_partial_path raises error' do
      let(:args) { [double('string_node', type: :str, children: ['user'])] }

      before do
        allow(processor).to receive(:resolve_partial_path).and_raise(StandardError, 'Path resolution failed')
      end

      it 'propagates the error' do
        expect {
          processor.send(:process_partial, args)
        }.to raise_error(StandardError, 'Path resolution failed')
      end
    end

    context 'with malformed hash arguments' do
      let(:malformed_pair) { double('malformed_pair', type: :pair, children: [nil, nil]) }
      let(:hash_node) { double('hash_node', type: :hash, children: [malformed_pair]) }
      let(:args) { [hash_node] }

      it 'handles malformed pairs gracefully' do
        expect {
          result = processor.send(:extract_partial_name, args)
          expect(result).to be_nil
        }.not_to raise_error
      end
    end
  end
end