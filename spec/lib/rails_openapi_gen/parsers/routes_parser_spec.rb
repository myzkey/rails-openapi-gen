require 'spec_helper'

RSpec.describe RailsOpenapiGen::Parsers::RoutesParser do
  let(:parser) { described_class.new }
  
  # Mock route objects
  let(:simple_route) do
    double('Route',
      verb: 'GET',
      path: double('Path', spec: '/api/users(.:format)'),
      defaults: { controller: 'api/users', action: 'index' },
      name: 'api_users'
    )
  end
  
  let(:nested_route_without_controller) do
    double('Route',
      verb: 'GET',
      path: double('Path', spec: '/api/users/:user_id/orders(.:format)'),
      defaults: { controller: 'api/orders', action: 'index' },
      name: 'api_user_orders'
    )
  end
  
  let(:nested_route_with_controller) do
    double('Route',
      verb: 'GET',
      path: double('Path', spec: '/api/users/:user_id/posts(.:format)'),
      defaults: { controller: 'api/users/posts', action: 'index' },
      name: 'api_user_posts'
    )
  end
  
  let(:deep_nested_route) do
    double('Route',
      verb: 'GET',
      path: double('Path', spec: '/api/v1/companies/:company_id/departments/:department_id/employees(.:format)'),
      defaults: { controller: 'api/v1/employees', action: 'index' },
      name: 'api_v1_company_department_employees'
    )
  end
  
  let(:route_without_name) do
    double('Route',
      verb: 'POST',
      path: double('Path', spec: '/api/orders(.:format)'),
      defaults: { controller: 'api/orders', action: 'create' },
      name: nil
    )
  end
  
  before do
    # Mock Rails.application.routes
    allow(Rails).to receive_message_chain(:application, :routes, :routes).and_return([
      simple_route,
      nested_route_without_controller,
      nested_route_with_controller,
      deep_nested_route,
      route_without_name
    ])
    
    # Mock Rails.root for file existence checks
    allow(Rails).to receive(:root).and_return(Pathname.new('/rails/app'))
  end
  
  describe '#parse' do
    it 'returns array of route information' do
      result = parser.parse
      expect(result).to be_an(Array)
      expect(result).not_to be_empty
    end
    
    it 'includes basic route information' do
      result = parser.parse
      first_route = result.first
      
      expect(first_route).to include(
        verb: 'GET',
        path: '/api/users',
        controller: 'api/users',
        action: 'index'
      )
    end
  end
  
  describe '#infer_controller_from_route' do
    context 'with simple routes' do
      it 'returns default controller when no inference needed' do
        result = parser.send(:infer_controller_from_route, simple_route)
        expect(result).to eq('api/users')
      end
    end
    
    context 'with nested routes' do
      before do
        # Mock file existence for nested controllers
        allow(File).to receive(:exist?).with('/rails/app/app/controllers/api/users/orders_controller.rb').and_return(true)
        allow(File).to receive(:exist?).with('/rails/app/app/controllers/api/v1/companies/departments/employees_controller.rb').and_return(true)
      end
      
      it 'infers nested controller from route name' do
        result = parser.send(:infer_controller_from_route, nested_route_without_controller)
        expect(result).to eq('api/users/orders')
      end
      
      it 'respects explicit controller definition' do
        result = parser.send(:infer_controller_from_route, nested_route_with_controller)
        expect(result).to eq('api/users/posts')
      end
      
      it 'handles deep nesting with proper pluralization' do
        result = parser.send(:infer_controller_from_route, deep_nested_route)
        expect(result).to eq('api/v1/companies/departments/employees')
      end
    end
    
    context 'with routes without names' do
      it 'returns default controller when route has no name' do
        result = parser.send(:infer_controller_from_route, route_without_name)
        expect(result).to eq('api/orders')
      end
    end
    
    context 'when inferred controller file does not exist' do
      before do
        allow(File).to receive(:exist?).and_return(false)
      end
      
      it 'falls back to default controller' do
        result = parser.send(:infer_controller_from_route, nested_route_without_controller)
        expect(result).to eq('api/orders')
      end
    end
  end
  
  describe 'route filtering' do
    let(:internal_route) do
      double('Route',
        verb: 'GET',
        path: double('Path', spec: '/rails/info/properties(.:format)'),
        defaults: { controller: 'rails/info', action: 'properties' },
        name: 'rails_info_properties'
      )
    end
    
    let(:asset_route) do
      double('Route',
        verb: 'GET',
        path: double('Path', spec: '/assets/*path(.:format)'),
        defaults: { controller: 'assets', action: 'serve' },
        name: nil
      )
    end
    
    before do
      allow(Rails).to receive_message_chain(:application, :routes, :routes).and_return([
        simple_route,
        internal_route,
        asset_route
      ])
    end
    
    it 'filters out Rails internal routes' do
      result = parser.parse
      controllers = result.map { |r| r[:controller] }
      
      expect(controllers).not_to include('rails/info')
      expect(controllers).to include('api/users')
    end
    
    it 'handles routes with special path patterns' do
      result = parser.parse
      paths = result.map { |r| r[:path] }
      
      expect(paths).not_to include('/assets/*path')
    end
  end
  
  describe 'parameter extraction' do
    it 'extracts path parameters correctly' do
      result = parser.parse
      nested_route_info = result.find { |r| r[:controller] == 'api/users/orders' }
      
      expect(nested_route_info).not_to be_nil
      expect(nested_route_info[:path]).to eq('/api/users/:user_id/orders')
    end
    
    it 'handles multiple parameters in path' do
      result = parser.parse
      deep_route_info = result.find { |r| r[:name] == 'api_v1_company_department_employees' }
      
      expect(deep_route_info).not_to be_nil
      expect(deep_route_info[:path]).to include(':company_id')
      expect(deep_route_info[:path]).to include(':department_id')
    end
  end
end