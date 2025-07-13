require 'spec_helper'

RSpec.describe RailsOpenapiGen::Parsers::Jbuilder::AstParser do
  # Skip tests that require actual file parsing due to Parser version compatibility issues
  before(:all) do
    if RUBY_VERSION < '3.1.7'
      skip "Skipping AST parser tests due to Parser gem version compatibility issues"
    end
  end
  let(:parser) { described_class.new(file_path) }

  describe '#parse' do
    context 'with simple array template' do
      let(:file_path) { 'test_array.json.jbuilder' }
      let(:content) do
        <<~JBUILDER
          # @openapi orders:array
          json.array! @orders do |order|
            # @openapi id:integer description:"Order ID"
            json.id order.id
          #{'  '}
            # @openapi order_number:string description:"Order number"
            json.order_number order.order_number
          #{'  '}
            # @openapi total_amount:number description:"Total amount"
            json.total_amount order.total_amount
          end
        JBUILDER
      end

      before { File.write(file_path, content) }
      after { File.delete(file_path) if File.exist?(file_path) }

      it 'returns ArrayNode as root' do
        result = parser.parse
        expect(result).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
        expect(result.is_root_array).to be true
      end

      it 'creates a single object item with all properties' do
        result = parser.parse
        expect(result.items.length).to eq(1)

        item = result.items.first
        expect(item).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
        expect(item.properties.map(&:property_name)).to match_array(%w[id order_number total_amount])
      end

      it 'preserves comment data for properties' do
        result = parser.parse
        item = result.items.first

        id_prop = item.properties.find { |p| p.property_name == 'id' }
        expect(id_prop.comment_data.type).to eq('integer')
        expect(id_prop.comment_data.description).to eq('Order ID')
      end
    end

    context 'with nested array blocks' do
      let(:file_path) { 'test_nested_array.json.jbuilder' }
      let(:content) do
        <<~JBUILDER
          json.order do
            # @openapi id:integer
            json.id @order.id
          #{'  '}
            # @openapi items:array
            json.array! @order.items do |item|
              # @openapi product_id:integer
              json.product_id item.product_id
          #{'    '}
              # @openapi quantity:integer
              json.quantity item.quantity
            end
          end
        JBUILDER
      end

      before { File.write(file_path, content) }
      after { File.delete(file_path) if File.exist?(file_path) }

      it 'creates proper nested structure' do
        result = parser.parse
        expect(result).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)

        order_prop = result.properties.find { |p| p.property_name == 'order' }
        expect(order_prop).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)

        # Find the array property within order
        array_prop = order_prop.properties.find { |p| p.is_a?(RailsOpenapiGen::AstNodes::ArrayNode) }
        expect(array_prop).not_to be_nil
        expect(array_prop.items.length).to eq(1)

        # Check array item structure
        item = array_prop.items.first
        expect(item).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
        expect(item.properties.map(&:property_name)).to match_array(%w[product_id quantity])
      end
    end

    context 'with partials in array' do
      let(:file_path) { 'test_array_partial.json.jbuilder' }
      let(:partial_path) { 'test/_order.json.jbuilder' }
      let(:content) do
        <<~JBUILDER
          # @openapi orders:array
          json.array! @orders do |order|
            json.partial! partial: 'test/order', locals: { order: order }
          end
        JBUILDER
      end
      let(:partial_content) do
        <<~JBUILDER
          # @openapi id:integer description:"Order ID"
          json.id order.id

          # @openapi shipping_address:object description:"Shipping address"
          json.shipping_address do
            # @openapi street:string
            json.street order.shipping_address.street
          #{'  '}
            # @openapi city:string
            json.city order.shipping_address.city
          end
        JBUILDER
      end

      before do
        Dir.mkdir('test') unless Dir.exist?('test')
        File.write(file_path, content)
        File.write(partial_path, partial_content)
      end

      after do
        File.delete(file_path) if File.exist?(file_path)
        File.delete(partial_path) if File.exist?(partial_path)
        Dir.rmdir('test') if Dir.exist?('test') && Dir.empty?('test')
      end

      it 'processes partial properties into array items' do
        result = parser.parse
        expect(result).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)

        item = result.items.first
        expect(item).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)

        # Should have properties from the partial
        property_names = item.properties.map(&:property_name)
        expect(property_names).to include('id', 'shipping_address')

        # Check nested object
        shipping = item.properties.find { |p| p.property_name == 'shipping_address' }
        expect(shipping).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
        expect(shipping.properties.map(&:property_name)).to match_array(%w[street city])
      end
    end

    context 'with Pathname file paths' do
      let(:file_path) { Pathname.new('test_pathname.json.jbuilder') }
      let(:content) do
        <<~JBUILDER
          # @openapi id:integer
          json.id @user.id
        JBUILDER
      end

      before { File.write(file_path.to_s, content) }
      after { File.delete(file_path.to_s) if File.exist?(file_path.to_s) }

      it 'handles Pathname objects correctly' do
        expect { parser.parse }.not_to raise_error
        result = parser.parse
        expect(result).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
        expect(result.properties.first.property_name).to eq('id')
      end
    end

    context 'with conditional properties' do
      let(:file_path) { 'test_conditional.json.jbuilder' }
      let(:content) do
        <<~JBUILDER
          # @openapi id:integer
          json.id @user.id

          # @openapi conditional:true
          if @user.premium?
            # @openapi premium_features:object
            json.premium_features do
              # @openapi feature_list:array
              json.feature_list @user.features
            end
          end
        JBUILDER
      end

      before { File.write(file_path, content) }
      after { File.delete(file_path) if File.exist?(file_path) }

      it 'marks conditional properties correctly' do
        result = parser.parse

        premium_prop = result.properties.find { |p| p.property_name == 'premium_features' }
        expect(premium_prop).not_to be_nil
        expect(premium_prop.is_conditional).to be true
      end
    end
  end

  describe '#find_views_root' do
    let(:parser) { described_class.new('dummy.json.jbuilder') }

    context 'with standard Rails structure' do
      it 'finds views root from deep path' do
        path = '/path/to/app/views/api/v1/users/show.json.jbuilder'
        result = parser.send(:find_views_root, path)
        expect(result).to eq('/path/to/app/views')
      end

      it 'handles Pathname objects' do
        path = Pathname.new('/path/to/app/views/api/users/index.json.jbuilder')
        result = parser.send(:find_views_root, path)
        expect(result).to eq('/path/to/app/views')
      end
    end

    context 'with non-standard structure' do
      it 'returns dirname when views directory not found' do
        path = '/custom/path/templates/users.json.jbuilder'
        result = parser.send(:find_views_root, path)
        expect(result).to eq('/custom/path/templates')
      end
    end
  end

  describe '#resolve_partial_path' do
    let(:file_path) { '/app/views/api/users/show.json.jbuilder' }
    let(:parser) { described_class.new(file_path) }

    it 'resolves simple partial names' do
      result = parser.send(:resolve_partial_path, 'user')
      expect(result).to eq('/app/views/api/users/_user.json.jbuilder')
    end

    it 'resolves namespaced partials' do
      result = parser.send(:resolve_partial_path, 'api/users/user')
      expect(result).to eq('/app/views/api/users/_user.json.jbuilder')
    end

    it 'handles partials that already have underscore' do
      result = parser.send(:resolve_partial_path, '_user')
      expect(result).to eq('/app/views/api/users/_user.json.jbuilder')
    end

    it 'handles absolute paths' do
      result = parser.send(:resolve_partial_path, '/custom/path')
      expect(result).to eq('/custom/path')
    end
  end
end
