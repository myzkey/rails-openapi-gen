require 'spec_helper'

RSpec.describe 'Example Use Cases Integration' do
  describe 'Orders endpoint with nested resources' do
    let(:orders_index_template) do
      <<~JBUILDER
        # @openapi orders:array
        json.array! @orders do |order|
          json.partial! partial: 'api/users/model/order',
                        locals: { order: order }
        end
      JBUILDER
    end
    
    let(:order_partial) do
      <<~JBUILDER
        # @openapi id:integer description:"Order ID"
        json.id order.id
        
        # @openapi order_number:string description:"Order number"
        json.order_number order.order_number
        
        # @openapi total_amount:number description:"Total amount"
        json.total_amount order.total_amount
        
        # @openapi status:string enum:[pending,processing,shipped,delivered] description:"Order status"
        json.status order.status
        
        # @openapi placed_at:string format:date-time description:"Order placement timestamp"
        json.placed_at order.placed_at
        
        # @openapi order_items:array description:"Order items"
        json.order_items do
          json.array! order.order_items do |item|
            json.partial! 'api/users/model/order_item', order_item: item
          end
        end
        
        json.shipping_address do
          json.partial! 'api/users/model/shipping_address', 
                        shipping_address: order.shipping_address
        end
        
        json.payment_method do
          json.partial! 'api/users/model/payment_method',
                        payment_method: order.payment_method
        end
      JBUILDER
    end
    
    let(:order_item_partial) do
      <<~JBUILDER
        # @openapi id:integer
        json.id order_item.id
        
        # @openapi product_id:integer
        json.product_id order_item.product_id
        
        # @openapi quantity:integer
        json.quantity order_item.quantity
        
        # @openapi unit_price:number
        json.unit_price order_item.unit_price
        
        # @openapi total_price:number
        json.total_price order_item.total_price
      JBUILDER
    end
    
    let(:shipping_address_partial) do
      <<~JBUILDER
        # @openapi id:integer
        json.id shipping_address.id
        
        # @openapi street:string
        json.street shipping_address.street
        
        # @openapi city:string
        json.city shipping_address.city
        
        # @openapi state:string
        json.state shipping_address.state
        
        # @openapi zip_code:string
        json.zip_code shipping_address.zip_code
        
        # @openapi country:string
        json.country shipping_address.country
      JBUILDER
    end
    
    let(:payment_method_partial) do
      <<~JBUILDER
        # @openapi id:integer
        json.id payment_method.id
        
        # @openapi type:string enum:[credit_card,debit_card,paypal]
        json.type payment_method.type
        
        # @openapi brand:string required:false
        json.brand payment_method.brand
        
        # @openapi last4:string required:false
        json.last4 payment_method.last4
        
        # @openapi expiry:string required:false
        json.expiry payment_method.expiry
        
        # @openapi holder_name:string
        json.holder_name payment_method.holder_name
        
        # @openapi provider:string
        json.provider payment_method.provider
      JBUILDER
    end
    
    before do
      # Create directory structure
      FileUtils.mkdir_p('app/views/api/users/orders')
      FileUtils.mkdir_p('app/views/api/users/model')
      
      # Write templates
      File.write('app/views/api/users/orders/index.json.jbuilder', orders_index_template)
      File.write('app/views/api/users/model/_order.json.jbuilder', order_partial)
      File.write('app/views/api/users/model/_order_item.json.jbuilder', order_item_partial)
      File.write('app/views/api/users/model/_shipping_address.json.jbuilder', shipping_address_partial)
      File.write('app/views/api/users/model/_payment_method.json.jbuilder', payment_method_partial)
    end
    
    after do
      FileUtils.rm_rf('app')
    end
    
    it 'generates correct schema for orders endpoint' do
      parser = RailsOpenapiGen::Parsers::Jbuilder::AstParser.new('app/views/api/users/orders/index.json.jbuilder')
      ast = parser.parse
      
      # Should be root array
      expect(ast).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
      expect(ast.is_root_array).to be true
      
      # Should have one object item with order properties
      expect(ast.items.length).to eq(1)
      item = ast.items.first
      expect(item).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
      
      # Verify order properties
      property_names = item.properties.map(&:property_name)
      puts "DEBUG: Item properties: #{property_names.inspect}" if ENV['DEBUG']
      puts "DEBUG: Item class: #{item.class}" if ENV['DEBUG']
      puts "DEBUG: Item properties detail: #{item.properties.map { |p| "#{p.property_name} (#{p.class.name})" }}" if ENV['DEBUG']
      expect(property_names).to include('id', 'order_number', 'total_amount', 'status', 'placed_at')
      
      # Verify nested array (order_items) - it's an ObjectNode containing an ArrayNode
      order_items_prop = item.properties.find { |p| p.property_name == 'order_items' }
      expect(order_items_prop).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
      # The object should contain an array
      expect(order_items_prop.properties.first).to be_a(RailsOpenapiGen::AstNodes::ArrayNode)
      
      # Verify nested objects
      shipping_prop = item.properties.find { |p| p.property_name == 'shipping_address' }
      expect(shipping_prop).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
      expect(shipping_prop.properties.map(&:property_name)).to include('street', 'city', 'state')
      
      payment_prop = item.properties.find { |p| p.property_name == 'payment_method' }
      expect(payment_prop).to be_a(RailsOpenapiGen::AstNodes::ObjectNode)
      expect(payment_prop.properties.map(&:property_name)).to include('type', 'brand', 'provider')
    end
    
    it 'generates valid OpenAPI schema using AstToSchemaProcessor' do
      parser = RailsOpenapiGen::Parsers::Jbuilder::AstParser.new('app/views/api/users/orders/index.json.jbuilder')
      ast = parser.parse
      
      processor = RailsOpenapiGen::Processors::AstToSchemaProcessor.new
      schema = processor.process_to_schema(ast)
      
      # Root should be array
      expect(schema['type']).to eq('array')
      expect(schema['items']).to be_a(Hash)
      
      # Items should be objects with correct properties
      items_schema = schema['items']
      expect(items_schema['type']).to eq('object')
      expect(items_schema['properties']).to include('id', 'order_number', 'total_amount')
      
      # Check nested array structure
      # order_items is an object containing an array due to template structure:
      # json.order_items do
      #   json.array! order.order_items do |item|
      order_items_schema = items_schema['properties']['order_items']
      expect(order_items_schema['type']).to eq('object')
      expect(order_items_schema['properties']['items']).to be_a(Hash)
      expect(order_items_schema['properties']['items']['type']).to eq('array')
      expect(order_items_schema['properties']['items']['items']['type']).to eq('object')
      expect(order_items_schema['properties']['items']['items']['properties']).to include('product_id', 'quantity')
      
      # Check required fields
      expect(items_schema['required']).to include('id', 'order_number', 'total_amount')
      
      # Check optional fields (marked with required:false)
      payment_method_schema = items_schema['properties']['payment_method']
      payment_required = payment_method_schema['required']
      expect(payment_required).not_to include('brand', 'last4', 'expiry')
      expect(payment_required).to include('holder_name', 'provider')
    end
  end
  
  describe 'Route inference for nested resources' do
    let(:routes_parser) { RailsOpenapiGen::Parsers::RoutesParser.new }
    
    before do
      # Mock Rails routes
      routes = [
        double('Route',
          verb: 'GET',
          path: double('Path', spec: '/api/users/:user_id/orders(.:format)'),
          defaults: { controller: 'api/orders', action: 'index' },
          name: 'api_user_orders'
        ),
        double('Route',
          verb: 'GET',
          path: double('Path', spec: '/api/v1/cooperation/professionals/search(.:format)'),
          defaults: { controller: 'api/v1/cooperation/professionals', action: 'search' },
          name: 'api_v1_cooperation_professionals_search'
        )
      ]
      
      allow(Rails).to receive_message_chain(:application, :routes, :routes).and_return(routes)
      allow(Rails).to receive(:root).and_return(Pathname.new('/rails/app'))
      
      # Mock controller file existence
      allow(File).to receive(:exist?).with('/rails/app/app/controllers/api/users/orders_controller.rb').and_return(true)
      allow(File).to receive(:exist?).with('/rails/app/app/controllers/api/v1s/cooperations/professionals_controller.rb').and_return(false)
    end
    
    it 'correctly infers nested controller paths' do
      results = routes_parser.parse
      
      orders_route = results.find { |r| r[:name] == 'api_user_orders' }
      expect(orders_route).not_to be_nil
      expect(orders_route[:controller]).to eq('api/users/orders')
      
      professionals_route = results.find { |r| r[:name] == 'api_v1_cooperation_professionals_search' }
      expect(professionals_route).not_to be_nil
      expect(professionals_route[:controller]).to eq('api/v1/cooperation/professionals')
    end
  end
  
  describe 'Complex conditional rendering' do
    let(:user_show_template) do
      <<~JBUILDER
        # @openapi id:integer
        json.id @user.id
        
        # @openapi name:string
        json.name @user.name
        
        # @openapi email:string
        json.email @user.email
        
        # @openapi role:string enum:[admin,moderator,user]
        json.role @user.role
        
        # @openapi conditional:true
        if current_user.admin?
          # @openapi admin_notes:string description:"Admin-only notes"
          json.admin_notes @user.admin_notes
        end
        
        # @openapi conditional:true
        if @user.profile.present?
          # @openapi profile:object description:"User profile information"
          json.profile do
            # @openapi bio:string
            json.bio @user.profile.bio
            
            # @openapi avatar_url:string
            json.avatar_url @user.profile.avatar_url
            
            # @openapi verified:boolean
            json.verified @user.profile.verified
          end
        end
        
        # @openapi posts:array
        json.posts @user.posts do |post|
          # @openapi id:integer
          json.id post.id
          
          # @openapi title:string
          json.title post.title
          
          # @openapi published:boolean
          json.published post.published
        end
      JBUILDER
    end
    
    before do
      FileUtils.mkdir_p('app/views/users')
      File.write('app/views/users/show.json.jbuilder', user_show_template)
    end
    
    after do
      FileUtils.rm_rf('app')
    end
    
    it 'correctly handles conditional properties' do
      parser = RailsOpenapiGen::Parsers::Jbuilder::AstParser.new('app/views/users/show.json.jbuilder')
      ast = parser.parse
      
      # Find conditional properties
      admin_notes = ast.properties.find { |p| p.property_name == 'admin_notes' }
      expect(admin_notes).not_to be_nil
      expect(admin_notes.is_conditional).to be true
      
      profile = ast.properties.find { |p| p.property_name == 'profile' }
      expect(profile).not_to be_nil
      expect(profile.is_conditional).to be true
      
      # Non-conditional properties
      id_prop = ast.properties.find { |p| p.property_name == 'id' }
      expect(id_prop.is_conditional).to be false
    end
    
    it 'generates schema with conditional properties marked as optional' do
      parser = RailsOpenapiGen::Parsers::Jbuilder::AstParser.new('app/views/users/show.json.jbuilder')
      ast = parser.parse
      
      processor = RailsOpenapiGen::Processors::AstToSchemaProcessor.new
      schema = processor.process_to_schema(ast)
      
      # Required should not include conditional properties
      expect(schema['required']).to include('id', 'name', 'email', 'role', 'posts')
      expect(schema['required']).not_to include('admin_notes', 'profile')
      
      # But properties should still be defined
      expect(schema['properties']).to include('admin_notes', 'profile')
    end
  end
end