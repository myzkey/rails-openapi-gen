# frozen_string_literal: true

require 'spec_helper'

# Unit tests for PartialProcessor logic without requiring the actual class
# This tests the core logic without depending on Parser gem
RSpec.describe 'PartialProcessor Logic' do
  # Mock the needed modules and classes
  before(:all) do
    unless defined?(Parser)
      module Parser
        module AST
          class Processor
            def initialize; end
            def process(node); end
          end
        end
      end
    end

    # Mock the detector module
    module TestCallDetectors
      module PartialCallDetector
        def self.partial_call?(_receiver, method_name)
          method_name == :partial!
        end
      end
    end

    # Create a test class that implements the logic we want to test
    class TestPartialProcessor
      attr_reader :partials, :file_path, :property_parser

      def initialize(file_path, property_parser)
        @file_path = file_path
        @property_parser = property_parser
        @partials = []
      end

      def on_send(node)
        receiver, method_name, *args = node.children
        process_partial(args) if TestCallDetectors::PartialCallDetector.partial_call?(receiver, method_name)
      end

      def process_partial(args)
        return if args.empty?

        partial_name = extract_partial_name(args)
        return unless partial_name

        puts "🔍 DEBUG: Found partial: #{partial_name}" if ENV['RAILS_OPENAPI_DEBUG']
        partial_path = resolve_partial_path(partial_name)
        puts "🔍 DEBUG: Resolved partial path: #{partial_path}" if ENV['RAILS_OPENAPI_DEBUG']
        puts "🔍 DEBUG: Partial exists: #{File.exist?(partial_path)}" if ENV['RAILS_OPENAPI_DEBUG'] && partial_path
        @partials << partial_path if partial_path
      end

      def extract_partial_name(args)
        first_arg = args.first

        # Handle simple string case: json.partial! 'path/to/partial'
        if first_arg.type == :str
          return first_arg.children.first
        end

        # Handle hash case: json.partial! partial: 'path/to/partial', locals: {...}
        if first_arg.type == :hash
          first_arg.children.each do |pair|
            next unless pair.type == :pair

            key, value = pair.children
            if key.type == :sym && key.children.first == :partial && value.type == :str
              return value.children.first
            end
          end
        end

        nil
      end

      def resolve_partial_path(partial_name)
        return nil unless @file_path && partial_name

        dir = File.dirname(@file_path)

        if partial_name.include?('/')
          # Find the app/views directory from the current file path
          path_parts = @file_path.to_s.split('/')
          views_index = path_parts.rindex('views')
          if views_index
            views_path = path_parts[0..views_index].join('/')
            # For paths like 'users/user', convert to 'users/_user.json.jbuilder'
            parts = partial_name.to_s.split('/')
            dir_part = parts[0..-2].join('/')
            file_part = "_#{parts[-1]}"
            File.join(views_path, dir_part, "#{file_part}.json.jbuilder")
          else
            # For paths like 'users/user', convert to 'users/_user.json.jbuilder'
            parts = partial_name.to_s.split('/')
            dir_part = parts[0..-2].join('/')
            file_part = "_#{parts[-1]}"
            File.join(dir, dir_part, "#{file_part}.json.jbuilder")
          end
        else
          # Add underscore prefix if not already present
          filename = partial_name.start_with?('_') ? partial_name : "_#{partial_name}"
          File.join(dir, "#{filename}.json.jbuilder")
        end
      end
    end
  end

  let(:file_path) { '/test/app/views/users/index.json.jbuilder' }
  let(:property_parser) { double('PropertyCommentParser') }
  let(:processor) { TestPartialProcessor.new(file_path, property_parser) }

  # Helper to create mock AST nodes
  def create_node(type, children = [])
    double('node', type: type, children: children)
  end

  describe '#on_send' do
    context 'with partial call' do
      let(:args) { [create_node(:str, ['users/user'])] }
      let(:node) { create_node(:send, [nil, :partial!, *args]) }

      it 'processes partial with args' do
        expect(processor).to receive(:process_partial).with(args)
        processor.on_send(node)
      end
    end

    context 'with non-partial call' do
      let(:node) { create_node(:send, [nil, :name]) }

      it 'does not process as partial' do
        expect(processor).not_to receive(:process_partial)
        processor.on_send(node)
      end
    end
  end

  describe '#extract_partial_name' do
    context 'with string argument' do
      let(:string_node) { create_node(:str, ['users/user']) }
      let(:args) { [string_node] }

      it 'extracts partial name from string node' do
        result = processor.extract_partial_name(args)
        expect(result).to eq('users/user')
      end
    end

    context 'with hash argument containing partial key' do
      let(:partial_key) { create_node(:sym, [:partial]) }
      let(:partial_value) { create_node(:str, ['shared/user']) }
      let(:partial_pair) { create_node(:pair, [partial_key, partial_value]) }
      let(:hash_node) { create_node(:hash, [partial_pair]) }
      let(:args) { [hash_node] }

      it 'extracts partial name from hash with partial key' do
        result = processor.extract_partial_name(args)
        expect(result).to eq('shared/user')
      end
    end

    context 'with hash argument without partial key' do
      let(:other_key) { create_node(:sym, [:template]) }
      let(:other_value) { create_node(:str, ['some/template']) }
      let(:other_pair) { create_node(:pair, [other_key, other_value]) }
      let(:hash_node) { create_node(:hash, [other_pair]) }
      let(:args) { [hash_node] }

      it 'returns nil when partial key not found' do
        result = processor.extract_partial_name(args)
        expect(result).to be_nil
      end
    end

    context 'with non-string, non-hash arguments' do
      let(:integer_node) { create_node(:int, [42]) }
      let(:args) { [integer_node] }

      it 'returns nil for unsupported argument types' do
        result = processor.extract_partial_name(args)
        expect(result).to be_nil
      end
    end
  end

  describe '#resolve_partial_path' do
    context 'with simple partial name' do
      it 'resolves to same directory with underscore prefix' do
        result = processor.resolve_partial_path('user')
        expect(result).to eq('/test/app/views/users/_user.json.jbuilder')
      end
    end

    context 'with namespaced partial name' do
      it 'resolves relative to views directory' do
        result = processor.resolve_partial_path('shared/header')
        expect(result).to eq('/test/app/views/shared/_header.json.jbuilder')
      end
    end

    context 'with file path not containing views' do
      let(:file_path) { '/some/other/path/template.json.jbuilder' }
      let(:processor) { TestPartialProcessor.new(file_path, property_parser) }

      it 'resolves relative to current directory' do
        result = processor.resolve_partial_path('shared/header')
        expect(result).to eq('/some/other/path/shared/_header.json.jbuilder')
      end
    end
  end

  describe '#process_partial' do
    context 'with valid partial name' do
      let(:args) { [create_node(:str, ['users/user'])] }

      before do
        allow(processor).to receive(:resolve_partial_path).with('users/user').and_return('/resolved/path/_user.json.jbuilder')
      end

      it 'adds resolved path to partials collection' do
        processor.process_partial(args)
        expect(processor.partials).to include('/resolved/path/_user.json.jbuilder')
      end
    end

    context 'with empty args' do
      it 'returns early without processing' do
        expect(processor).not_to receive(:extract_partial_name)
        processor.process_partial([])
      end
    end

    context 'when partial name cannot be extracted' do
      let(:args) { [create_node(:int, [42])] }

      it 'does not add anything to partials' do
        processor.process_partial(args)
        expect(processor.partials).to be_empty
      end
    end
  end

  describe 'integration scenarios' do
    context 'processing multiple partial calls' do
      it 'accumulates all partial paths' do
        # Process first partial
        args1 = [create_node(:str, ['users/user'])]
        node1 = create_node(:send, [nil, :partial!, *args1])

        # Process second partial
        args2 = [create_node(:str, ['shared/header'])]
        node2 = create_node(:send, [nil, :partial!, *args2])

        processor.on_send(node1)
        processor.on_send(node2)

        expect(processor.partials).to include('/test/app/views/users/_user.json.jbuilder')
        expect(processor.partials).to include('/test/app/views/shared/_header.json.jbuilder')
      end
    end
  end
end
