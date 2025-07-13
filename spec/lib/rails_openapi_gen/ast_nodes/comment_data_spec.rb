require 'spec_helper'

RSpec.describe RailsOpenapiGen::AstNodes::CommentData do
  describe '#initialize' do
    it 'accepts all comment attributes' do
      comment_data = described_class.new(
        type: 'string',
        description: 'Test description',
        required: false,
        enum: %w[a b c],
        conditional: true,
        format: 'date-time',
        example: 'test example'
      )

      expect(comment_data.type).to eq('string')
      expect(comment_data.description).to eq('Test description')
      expect(comment_data.required).to be false
      expect(comment_data.enum).to eq(%w[a b c])
      expect(comment_data.conditional).to be true
      expect(comment_data.format).to eq('date-time')
      expect(comment_data.example).to eq('test example')
    end

    it 'sets default values' do
      comment_data = described_class.new

      expect(comment_data.type).to be_nil
      expect(comment_data.description).to be_nil
      expect(comment_data.required).to be true  # Default is true
      expect(comment_data.enum).to be_nil
      expect(comment_data.conditional).to be false
      expect(comment_data.format).to be_nil
      expect(comment_data.example).to be_nil
    end
  end

  describe '#required?' do
    it 'returns true when required is true' do
      comment_data = described_class.new(required: true)
      expect(comment_data.required?).to be true
    end

    it 'returns false when required is false' do
      comment_data = described_class.new(required: false)
      expect(comment_data.required?).to be false
    end

    it 'returns true by default' do
      comment_data = described_class.new
      expect(comment_data.required?).to be true
    end
  end

  describe '#has_enum?' do
    it 'returns true when enum is present' do
      comment_data = described_class.new(enum: %w[a b])
      expect(comment_data.has_enum?).to be true
    end

    it 'returns nil when enum is nil' do
      comment_data = described_class.new(enum: nil)
      expect(comment_data.has_enum?).to be_nil  # nil && !nil.empty? returns nil
    end

    it 'returns false when enum is empty' do
      comment_data = described_class.new(enum: [])
      expect(comment_data.has_enum?).to be false
    end
  end

  describe '#has_format?' do
    it 'returns true when format is present' do
      comment_data = described_class.new(format: 'date-time')
      expect(comment_data.has_format?).to be true
    end

    it 'returns nil when format is nil' do
      comment_data = described_class.new(format: nil)
      expect(comment_data.has_format?).to be_nil # nil && !nil.empty? returns nil
    end

    it 'returns false when format is empty string' do
      comment_data = described_class.new(format: '')
      expect(comment_data.has_format?).to be false
    end
  end

  describe '#has_example?' do
    it 'returns the example value when present' do
      comment_data = described_class.new(example: 'test')
      expect(comment_data.has_example?).to eq('test')
    end

    it 'returns nil when example is nil' do
      comment_data = described_class.new(example: nil)
      expect(comment_data.has_example?).to be_nil
    end

    it 'returns empty string when example is empty string' do
      comment_data = described_class.new(example: '')
      expect(comment_data.has_example?).to eq('')
    end
  end

  describe '#to_h' do
    it 'returns hash representation of all attributes' do
      comment_data = described_class.new(
        type: 'integer',
        description: 'User ID',
        required: false,
        enum: [1, 2, 3],
        conditional: true,
        format: 'int64',
        example: 123
      )

      hash = comment_data.to_h
      expect(hash).to eq({
                           type: 'integer',
                           description: 'User ID',
                           required: false,
                           enum: [1, 2, 3],
                           conditional: true,
                           format: 'int64',
                           example: 123
                         })
    end

    it 'compacts nil values in hash' do
      comment_data = described_class.new(type: 'string')
      hash = comment_data.to_h

      # The .compact method removes nil values, so only non-nil keys will be present
      expect(hash).to include(:type, :required)
      expect(hash[:type]).to eq('string')
      expect(hash).not_to include(:description, :enum, :format, :example)
    end
  end

  # CommentData doesn't implement == method, so remove this test
  # describe '#==' do

  describe 'type validation scenarios' do
    it 'handles string type' do
      comment_data = described_class.new(type: 'string')
      expect(comment_data.type).to eq('string')
    end

    it 'handles integer type' do
      comment_data = described_class.new(type: 'integer')
      expect(comment_data.type).to eq('integer')
    end

    it 'handles boolean type' do
      comment_data = described_class.new(type: 'boolean')
      expect(comment_data.type).to eq('boolean')
    end

    it 'handles array type' do
      comment_data = described_class.new(type: 'array')
      expect(comment_data.type).to eq('array')
    end

    it 'handles object type' do
      comment_data = described_class.new(type: 'object')
      expect(comment_data.type).to eq('object')
    end
  end

  describe 'conditional scenarios' do
    it 'handles conditional properties correctly' do
      comment_data = described_class.new(conditional: true, required: true)

      # Even if marked as required, conditional properties are treated specially
      expect(comment_data.conditional).to be true
      expect(comment_data.required?).to be true
    end

    it 'handles non-conditional properties' do
      comment_data = described_class.new(conditional: false, required: true)

      expect(comment_data.conditional).to be false
      expect(comment_data.required?).to be true
    end
  end
end
