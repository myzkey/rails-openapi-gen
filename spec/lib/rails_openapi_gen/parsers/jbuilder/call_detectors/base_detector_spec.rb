# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::BaseDetector do
  describe '.handles?' do
    it 'raises NotImplementedError' do
      expect do
        described_class.handles?(nil, :method_name, [])
      end.to raise_error(NotImplementedError, /must implement #handles\?/)
    end
  end

  describe '.priority' do
    it 'returns default priority of 0' do
      expect(described_class.priority).to eq(0)
    end
  end

  describe '.category' do
    it 'returns default category of :general' do
      expect(described_class.category).to eq(:general)
    end
  end

  describe '.description' do
    it 'returns default description' do
      expect(described_class.description).to eq("Base detector")
    end
  end

  describe '.json_receiver?' do
    context 'with nil receiver (implicit json calls)' do
      it 'returns true' do
        expect(described_class.send(:json_receiver?, nil)).to be true
      end
    end

    context 'with explicit json receiver' do
      let(:json_receiver) do
        # Mock a node representing "json" method call
        double('json_receiver', type: :send, children: [nil, :json])
      end

      it 'returns true for json receiver' do
        expect(described_class.send(:json_receiver?, json_receiver)).to be true
      end
    end

    context 'with other receivers' do
      let(:other_receiver) do
        # Mock a node representing "object" part of "object.method" call
        double('other_receiver', type: :send, children: [nil, :object])
      end

      it 'returns false for non-json receivers' do
        expect(described_class.send(:json_receiver?, other_receiver)).to be false
      end
    end

    context 'with nested json calls' do
      let(:nested_json) do
        # Mock a node representing "json.foo" part of "json.foo.bar" call
        # This is the receiver of the 'bar' method
        json_receiver = double('json_receiver', type: :send, children: [nil, :json])
        double('nested_json', type: :send, children: [json_receiver, :foo])
      end

      it 'returns false for nested calls (they should be handled by parent)' do
        expect(described_class.send(:json_receiver?, nested_json)).to be false
      end
    end
  end

  describe '.method_matches?' do
    context 'with symbol patterns' do
      it 'matches exact symbol' do
        expect(described_class.send(:method_matches?, :test, %i[test other])).to be true
      end

      it 'does not match different symbol' do
        expect(described_class.send(:method_matches?, :test, %i[other another])).to be false
      end
    end

    context 'with string patterns' do
      it 'matches exact string' do
        expect(described_class.send(:method_matches?, :test, %w[test other])).to be true
      end

      it 'converts string to symbol for comparison' do
        expect(described_class.send(:method_matches?, 'test', [:test])).to be true
      end
    end

    context 'with regex patterns' do
      it 'matches regex pattern' do
        pattern = /^test_/
        expect(described_class.send(:method_matches?, :test_method, [pattern])).to be true
      end

      it 'does not match non-matching regex' do
        pattern = /^test_/
        expect(described_class.send(:method_matches?, :other_method, [pattern])).to be false
      end
    end

    context 'with mixed patterns' do
      it 'matches any pattern in array' do
        patterns = [:exact, /^test_/, 'string_match']
        expect(described_class.send(:method_matches?, :test_method, patterns)).to be true
        expect(described_class.send(:method_matches?, :exact, patterns)).to be true
        expect(described_class.send(:method_matches?, :string_match, patterns)).to be true
      end
    end

    context 'with invalid patterns' do
      it 'ignores invalid pattern types' do
        patterns = [:valid, 123, nil]
        expect(described_class.send(:method_matches?, :valid, patterns)).to be true
        expect(described_class.send(:method_matches?, :invalid, patterns)).to be false
      end
    end

    context 'with empty patterns array' do
      it 'returns false' do
        expect(described_class.send(:method_matches?, :any_method, [])).to be false
      end
    end
  end

  describe '.args_contain_hash_with_keys?' do
    context 'with hash argument containing target keys' do
      let(:hash_arg) do
        # Mock a node representing { key: "value", other: "test" }
        key_key = double('key_key', type: :sym, children: [:key])
        key_value = double('key_value', type: :str, children: ['value'])
        key_pair = double('key_pair', type: :pair, children: [key_key, key_value])

        other_key = double('other_key', type: :sym, children: [:other])
        other_value = double('other_value', type: :str, children: ['test'])
        other_pair = double('other_pair', type: :pair, children: [other_key, other_value])

        double('hash', type: :hash, children: [key_pair, other_pair])
      end

      it 'returns true when hash contains any of the target keys' do
        result = described_class.send(:args_contain_hash_with_keys?, [hash_arg], %i[key missing])
        expect(result).to be true
      end

      it 'returns false when hash does not contain any target keys' do
        result = described_class.send(:args_contain_hash_with_keys?, [hash_arg], %i[missing absent])
        expect(result).to be false
      end
    end

    context 'with non-hash arguments' do
      let(:string_arg) { double('string', type: :str, children: ['test']) }
      let(:symbol_arg) { double('symbol', type: :sym, children: [:test]) }

      it 'returns false for non-hash arguments' do
        result = described_class.send(:args_contain_hash_with_keys?, [string_arg, symbol_arg], [:any])
        expect(result).to be false
      end
    end

    context 'with mixed arguments' do
      let(:hash_arg) do
        target_key = double('target_key', type: :sym, children: [:target])
        target_value = double('target_value', type: :str, children: ['value'])
        target_pair = double('target_pair', type: :pair, children: [target_key, target_value])
        double('hash', type: :hash, children: [target_pair])
      end
      let(:string_arg) { double('string', type: :str, children: ['test']) }

      it 'finds hash among mixed arguments' do
        result = described_class.send(:args_contain_hash_with_keys?, [string_arg, hash_arg], [:target])
        expect(result).to be true
      end
    end

    context 'with empty arguments' do
      it 'returns false' do
        result = described_class.send(:args_contain_hash_with_keys?, [], [:any])
        expect(result).to be false
      end
    end

    context 'with hash having string keys' do
      let(:string_key_hash) do
        # Mock a node representing { "key" => "value" }
        string_key = double('string_key', type: :str, children: ['key'])
        string_value = double('string_value', type: :str, children: ['value'])
        string_pair = double('string_pair', type: :pair, children: [string_key, string_value])
        double('hash', type: :hash, children: [string_pair])
      end

      it 'does not match string keys (only symbols)' do
        result = described_class.send(:args_contain_hash_with_keys?, [string_key_hash], [:key])
        expect(result).to be false
      end
    end

    context 'with complex hash structures' do
      let(:complex_hash) do
        # Mock a node representing { a: 1, b: { nested: true }, c: :symbol }
        a_key = double('a_key', type: :sym, children: [:a])
        a_value = double('a_value', type: :int, children: [1])
        a_pair = double('a_pair', type: :pair, children: [a_key, a_value])

        nested_key = double('nested_key', type: :sym, children: [:nested])
        nested_value = double('nested_value', type: true, children: [true])
        nested_pair = double('nested_pair', type: :pair, children: [nested_key, nested_value])
        nested_hash = double('nested_hash', type: :hash, children: [nested_pair])

        b_key = double('b_key', type: :sym, children: [:b])
        b_pair = double('b_pair', type: :pair, children: [b_key, nested_hash])

        c_key = double('c_key', type: :sym, children: [:c])
        c_value = double('c_value', type: :sym, children: [:symbol])
        c_pair = double('c_pair', type: :pair, children: [c_key, c_value])

        double('hash', type: :hash, children: [a_pair, b_pair, c_pair])
      end

      it 'matches top-level keys only' do
        result = described_class.send(:args_contain_hash_with_keys?, [complex_hash], %i[a b c])
        expect(result).to be true
      end

      it 'does not match nested keys' do
        result = described_class.send(:args_contain_hash_with_keys?, [complex_hash], [:nested])
        expect(result).to be false
      end
    end
  end

  describe '.extract_string_value' do
    context 'with string node' do
      let(:string_node) { double('string', type: :str, children: ['test string']) }

      it 'extracts string value' do
        result = described_class.send(:extract_string_value, string_node)
        expect(result).to eq("test string")
      end
    end

    context 'with symbol node' do
      let(:symbol_node) { double('symbol', type: :sym, children: [:test_symbol]) }

      it 'extracts symbol as string' do
        result = described_class.send(:extract_string_value, symbol_node)
        expect(result).to eq("test_symbol")
      end
    end

    context 'with other node types' do
      let(:integer_node) { double('integer', type: :int, children: [42]) }
      let(:boolean_node) { double('boolean', type: true, children: [true]) }

      it 'returns nil for non-string/symbol nodes' do
        expect(described_class.send(:extract_string_value, integer_node)).to be_nil
        expect(described_class.send(:extract_string_value, boolean_node)).to be_nil
      end
    end

    context 'with nil node' do
      it 'returns nil' do
        result = described_class.send(:extract_string_value, nil)
        expect(result).to be_nil
      end
    end

    context 'with empty string' do
      let(:empty_string_node) { double('empty_string', type: :str, children: ['']) }

      it 'extracts empty string' do
        result = described_class.send(:extract_string_value, empty_string_node)
        expect(result).to eq("")
      end
    end
  end

  describe '.literal_node?' do
    it 'returns true for string literals' do
      node = double('string', type: :str, children: ['test'])
      expect(described_class.send(:literal_node?, node)).to be true
    end

    it 'returns true for integer literals' do
      node = double('integer', type: :int, children: [42])
      expect(described_class.send(:literal_node?, node)).to be true
    end

    it 'returns true for float literals' do
      node = double('float', type: :float, children: [3.14])
      expect(described_class.send(:literal_node?, node)).to be true
    end

    it 'returns true for boolean literals' do
      true_node = double('true', type: :true, children: [true])
      false_node = double('false', type: :false, children: [false])
      expect(described_class.send(:literal_node?, true_node)).to be true
      expect(described_class.send(:literal_node?, false_node)).to be true
    end

    it 'returns true for nil literal' do
      node = double('nil', type: :nil, children: [nil])
      expect(described_class.send(:literal_node?, node)).to be true
    end

    it 'returns true for symbol literals' do
      node = double('symbol', type: :sym, children: [:symbol])
      expect(described_class.send(:literal_node?, node)).to be true
    end

    it 'returns false for variable references' do
      node = double('variable', type: :lvar, children: [:variable])
      expect(described_class.send(:literal_node?, node)).to be false
    end

    it 'returns false for method calls' do
      node = double('method_call', type: :send, children: [nil, :method_call])
      expect(described_class.send(:literal_node?, node)).to be false
    end

    it 'returns false for complex expressions' do
      node = double('complex', type: :send,
                               children: [double('left', type: :int, children: [1]), :+, double('right', type: :int, children: [2])])
      expect(described_class.send(:literal_node?, node)).to be false
    end
  end

  describe 'inheritance and extensibility' do
    let(:custom_detector_class) do
      Class.new(described_class) do
        def self.handles?(_receiver, method_name, _args = [])
          method_name == :custom_method
        end

        def self.priority
          10
        end

        def self.category
          :custom
        end

        def self.description
          "Custom detector for testing"
        end
      end
    end

    it 'allows subclasses to override class methods' do
      expect(custom_detector_class.handles?(nil, :custom_method)).to be true
      expect(custom_detector_class.handles?(nil, :other_method)).to be false
      expect(custom_detector_class.priority).to eq(10)
      expect(custom_detector_class.category).to eq(:custom)
      expect(custom_detector_class.description).to eq("Custom detector for testing")
    end

    it 'inherits utility methods from base class' do
      expect(custom_detector_class.send(:json_receiver?, nil)).to be true
      expect(custom_detector_class.send(:method_matches?, :test, [:test])).to be true
    end
  end

  describe 'real-world usage patterns' do
    context 'with typical Jbuilder method calls' do
      it 'correctly identifies json receiver patterns' do
        # Mock common Jbuilder patterns
        # For "json.property 'value'", the receiver would be nil (implicit json)
        receiver = nil

        expect(described_class.send(:json_receiver?, receiver)).to be true
      end

      it 'handles implicit json context' do
        # In Jbuilder templates, many calls are implicitly on json
        expect(described_class.send(:json_receiver?, nil)).to be true
      end
    end

    context 'with complex method matching scenarios' do
      it 'matches method patterns used in real detectors' do
        # Test patterns that would be used in real call detectors
        array_methods = [:array!, /^each/, :map]

        expect(described_class.send(:method_matches?, :array!, array_methods)).to be true
        expect(described_class.send(:method_matches?, :each_with_index, array_methods)).to be true
        expect(described_class.send(:method_matches?, :map, array_methods)).to be true
        expect(described_class.send(:method_matches?, :select, array_methods)).to be false
      end
    end

    context 'with hash argument detection' do
      it 'detects render options in arguments' do
        # Mock hash nodes to avoid Parser version compatibility issues
        template_key = double('key', type: :sym, children: [:template])
        template_value = double('value', type: :str, children: ['users/show'])
        template_pair = double('pair', type: :pair, children: [template_key, template_value])
        hash_with_template = double('hash', type: :hash, children: [template_pair])

        partial_key = double('key', type: :sym, children: [:partial])
        partial_value = double('value', type: :str, children: ['user'])
        partial_pair = double('pair', type: :pair, children: [partial_key, partial_value])
        hash_with_partial = double('hash', type: :hash, children: [partial_pair])

        format_key = double('key', type: :sym, children: [:format])
        format_value = double('value', type: :sym, children: [:json])
        format_pair = double('pair', type: :pair, children: [format_key, format_value])
        other_hash = double('hash', type: :hash, children: [format_pair])

        render_keys = %i[template partial]

        expect(described_class.send(:args_contain_hash_with_keys?, [hash_with_template], render_keys)).to be true
        expect(described_class.send(:args_contain_hash_with_keys?, [hash_with_partial], render_keys)).to be true
        expect(described_class.send(:args_contain_hash_with_keys?, [other_hash], render_keys)).to be false
      end
    end
  end
end
