# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsOpenapiGen::Parsers::Jbuilder::CallDetectors::BaseDetector do
  describe '.handles?' do
    it 'raises NotImplementedError' do
      expect {
        described_class.handles?(nil, :method_name, [])
      }.to raise_error(NotImplementedError, /must implement #handles\?/)
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
        # Creates a node representing "json" method call
        Parser::CurrentRuby.parse('json').children.first
      end

      it 'returns true for json receiver' do
        expect(described_class.send(:json_receiver?, json_receiver)).to be true
      end
    end

    context 'with other receivers' do
      let(:other_receiver) do
        # Creates a node representing "object.method" call
        # The receiver would be the 'object' part
        ast = Parser::CurrentRuby.parse('object.method')
        ast.children[0] # This is s(:send, nil, :object)
      end

      it 'returns false for non-json receivers' do
        expect(described_class.send(:json_receiver?, other_receiver)).to be false
      end
    end

    context 'with nested json calls' do
      let(:nested_json) do
        # Creates a node representing "json.foo.bar" where we're checking the receiver of 'bar'
        # which would be 'json.foo'
        ast = Parser::CurrentRuby.parse('json.foo.bar')
        ast.children[0] # This is s(:send, s(:send, nil, :json), :foo)
      end

      it 'returns false for nested calls (they should be handled by parent)' do
        expect(described_class.send(:json_receiver?, nested_json)).to be false
      end
    end
  end

  describe '.method_matches?' do
    context 'with symbol patterns' do
      it 'matches exact symbol' do
        expect(described_class.send(:method_matches?, :test, [:test, :other])).to be true
      end

      it 'does not match different symbol' do
        expect(described_class.send(:method_matches?, :test, [:other, :another])).to be false
      end
    end

    context 'with string patterns' do
      it 'matches exact string' do
        expect(described_class.send(:method_matches?, :test, ['test', 'other'])).to be true
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
        # Creates a node representing { key: "value", other: "test" }
        Parser::CurrentRuby.parse('{ key: "value", other: "test" }')
      end

      it 'returns true when hash contains any of the target keys' do
        result = described_class.send(:args_contain_hash_with_keys?, [hash_arg], [:key, :missing])
        expect(result).to be true
      end

      it 'returns false when hash does not contain any target keys' do
        result = described_class.send(:args_contain_hash_with_keys?, [hash_arg], [:missing, :absent])
        expect(result).to be false
      end
    end

    context 'with non-hash arguments' do
      let(:string_arg) { Parser::CurrentRuby.parse('"test"') }
      let(:symbol_arg) { Parser::CurrentRuby.parse(':test') }

      it 'returns false for non-hash arguments' do
        result = described_class.send(:args_contain_hash_with_keys?, [string_arg, symbol_arg], [:any])
        expect(result).to be false
      end
    end

    context 'with mixed arguments' do
      let(:hash_arg) { Parser::CurrentRuby.parse('{ target: "value" }') }
      let(:string_arg) { Parser::CurrentRuby.parse('"test"') }

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
        # Creates a node representing { "key" => "value" }
        Parser::CurrentRuby.parse('{ "key" => "value" }').children.first
      end

      it 'does not match string keys (only symbols)' do
        result = described_class.send(:args_contain_hash_with_keys?, [string_key_hash], [:key])
        expect(result).to be false
      end
    end

    context 'with complex hash structures' do
      let(:complex_hash) do
        # Creates a node representing { a: 1, b: { nested: true }, c: :symbol }
        Parser::CurrentRuby.parse('{ a: 1, b: { nested: true }, c: :symbol }')
      end

      it 'matches top-level keys only' do
        result = described_class.send(:args_contain_hash_with_keys?, [complex_hash], [:a, :b, :c])
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
      let(:string_node) { Parser::CurrentRuby.parse('"test string"') }

      it 'extracts string value' do
        result = described_class.send(:extract_string_value, string_node)
        expect(result).to eq("test string")
      end
    end

    context 'with symbol node' do
      let(:symbol_node) { Parser::CurrentRuby.parse(':test_symbol') }

      it 'extracts symbol as string' do
        result = described_class.send(:extract_string_value, symbol_node)
        expect(result).to eq("test_symbol")
      end
    end

    context 'with other node types' do
      let(:integer_node) { Parser::CurrentRuby.parse('42') }
      let(:boolean_node) { Parser::CurrentRuby.parse('true') }

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
      let(:empty_string_node) { Parser::CurrentRuby.parse('""') }

      it 'extracts empty string' do
        result = described_class.send(:extract_string_value, empty_string_node)
        expect(result).to eq("")
      end
    end
  end

  describe '.literal_node?' do
    it 'returns true for string literals' do
      node = Parser::CurrentRuby.parse('"test"')
      expect(described_class.send(:literal_node?, node)).to be true
    end

    it 'returns true for integer literals' do
      node = Parser::CurrentRuby.parse('42')
      expect(described_class.send(:literal_node?, node)).to be true
    end

    it 'returns true for float literals' do
      node = Parser::CurrentRuby.parse('3.14')
      expect(described_class.send(:literal_node?, node)).to be true
    end

    it 'returns true for boolean literals' do
      true_node = Parser::CurrentRuby.parse('true')
      false_node = Parser::CurrentRuby.parse('false')
      expect(described_class.send(:literal_node?, true_node)).to be true
      expect(described_class.send(:literal_node?, false_node)).to be true
    end

    it 'returns true for nil literal' do
      node = Parser::CurrentRuby.parse('nil')
      expect(described_class.send(:literal_node?, node)).to be true
    end

    it 'returns true for symbol literals' do
      node = Parser::CurrentRuby.parse(':symbol')
      expect(described_class.send(:literal_node?, node)).to be true
    end

    it 'returns false for variable references' do
      node = Parser::CurrentRuby.parse('variable')
      expect(described_class.send(:literal_node?, node)).to be false
    end

    it 'returns false for method calls' do
      node = Parser::CurrentRuby.parse('method_call')
      expect(described_class.send(:literal_node?, node)).to be false
    end

    it 'returns false for complex expressions' do
      node = Parser::CurrentRuby.parse('1 + 2')
      expect(described_class.send(:literal_node?, node)).to be false
    end
  end

  describe 'inheritance and extensibility' do
    let(:custom_detector_class) do
      Class.new(described_class) do
        def self.handles?(receiver, method_name, args = [])
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
        # Test common Jbuilder patterns
        json_call = Parser::CurrentRuby.parse('json.property "value"')
        receiver = json_call.children.first.children.first

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
        # Simulates detecting render template: "partial" calls
        hash_with_template = Parser::CurrentRuby.parse('{ template: "users/show" }')
        hash_with_partial = Parser::CurrentRuby.parse('{ partial: "user" }')
        other_hash = Parser::CurrentRuby.parse('{ format: :json }')

        render_keys = [:template, :partial]
        
        expect(described_class.send(:args_contain_hash_with_keys?, [hash_with_template], render_keys)).to be true
        expect(described_class.send(:args_contain_hash_with_keys?, [hash_with_partial], render_keys)).to be true
        expect(described_class.send(:args_contain_hash_with_keys?, [other_hash], render_keys)).to be false
      end
    end
  end
end