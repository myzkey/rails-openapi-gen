require 'spec_helper'

RSpec.describe RailsOpenapiGen::Parsers::RoutesParser do
  let(:file_checker) { double('FileChecker') }
  let(:parser) { described_class.new(file_checker: file_checker) }

  # Mock route objects with regex verbs (as Rails actually provides)
  let(:simple_route) do
    double('Route',
           verb: /^GET$/,
           path: double('Path', spec: '/api/users(.:format)'),
           defaults: { controller: 'api/users', action: 'index' },
           name: 'api_users')
  end

  let(:nested_route_without_controller) do
    double('Route',
           verb: /^GET$/,
           path: double('Path', spec: '/api/users/:user_id/orders(.:format)'),
           defaults: { controller: 'api/orders', action: 'index' },
           name: 'api_user_orders')
  end

  let(:nested_route_with_controller) do
    double('Route',
           verb: /^GET$/,
           path: double('Path', spec: '/api/users/:user_id/posts(.:format)'),
           defaults: { controller: 'api/users/posts', action: 'index' },
           name: 'api_user_posts')
  end

  let(:deep_nested_route) do
    double('Route',
           verb: /^GET$/,
           path: double('Path', spec: '/api/v1/companies/:company_id/departments/:department_id/employees(.:format)'),
           defaults: { controller: 'api/v1/employees', action: 'index' },
           name: 'api_v1_company_department_employees')
  end

  let(:route_without_name) do
    double('Route',
           verb: /^POST$/,
           path: double('Path', spec: '/api/orders(.:format)'),
           defaults: { controller: 'api/orders', action: 'create' },
           name: nil)
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

    # Mock file existence for nested controllers using the injected file_checker
    allow(file_checker).to receive(:call).and_return(false)
    allow(file_checker).to receive(:call).with('/rails/app/app/controllers/api/users/orders_controller.rb').and_return(true)
    allow(file_checker).to receive(:call).with('/rails/app/app/controllers/api/v1/companies/departments/employees_controller.rb').and_return(true)
    allow(file_checker).to receive(:call).with('/rails/app/app/controllers/api/users/posts_controller.rb').and_return(true)
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
        allow(file_checker).to receive(:call).and_return(false)
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
             verb: /^GET$/,
             path: double('Path', spec: '/rails/info/properties(.:format)'),
             defaults: { controller: 'rails/info', action: 'properties' },
             name: 'rails_info_properties')
    end

    let(:asset_route) do
      double('Route',
             verb: /^GET$/,
             path: double('Path', spec: '/assets/*path(.:format)'),
             defaults: { controller: 'assets', action: 'serve' },
             name: nil)
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

  describe 'enhanced features' do
    context 'verb extraction from regex' do
      it 'properly extracts HTTP method from regex verb' do
        result = parser.parse
        first_route = result.first

        expect(first_route[:verb]).to eq('GET')
        expect(first_route[:method]).to eq('GET')
      end

      it 'handles array verbs' do
        route_with_array_verb = double('Route',
                                       verb: [/^GET$/, /^POST$/],
                                       path: double('Path', spec: '/api/test(.:format)'),
                                       defaults: { controller: 'api/test', action: 'index' },
                                       name: 'api_test')

        allow(Rails).to receive_message_chain(:application, :routes, :routes).and_return([route_with_array_verb])

        result = parser.parse
        expect(result.first[:verb]).to eq('GET')
      end
    end

    context 'pluralization using ActiveSupport::Inflector' do
      let(:complex_route) do
        double('Route',
               verb: /^GET$/,
               path: double('Path', spec: '/api/companies/:company_id/people(.:format)'),
               defaults: { controller: 'api/people', action: 'index' },
               name: 'api_company_person')
      end

      before do
        allow(Rails).to receive_message_chain(:application, :routes, :routes).and_return([complex_route])
        allow(file_checker).to receive(:call).and_return(false)
        allow(file_checker).to receive(:call).with('/rails/app/app/controllers/api/companies/person_controller.rb').and_return(true)
      end

      it 'properly pluralizes irregular nouns using ActiveSupport::Inflector' do
        result = parser.send(:infer_controller_from_route, complex_route)
        expect(result).to eq('api/companies/person')
      end
    end

    context 'format suffix removal' do
      let(:complex_format_route) do
        double('Route',
               verb: /^GET$/,
               path: double('Path', spec: '/api/data(.json|.xml|.csv)'),
               defaults: { controller: 'api/data', action: 'show' },
               name: 'api_data')
      end

      it 'removes various format patterns' do
        allow(Rails).to receive_message_chain(:application, :routes, :routes).and_return([complex_format_route])

        result = parser.parse
        expect(result.first[:path]).to eq('/api/data')
      end
    end

    context 'dependency injection for file existence checking' do
      it 'uses injected file checker instead of File.exist?' do
        # Ensure our mock file_checker is called, not File.exist?
        expect(file_checker).to receive(:call).with('/rails/app/app/controllers/api/users/orders_controller.rb').and_return(true)

        result = parser.send(:infer_controller_from_route, nested_route_without_controller)
        expect(result).to eq('api/users/orders')
      end
    end
  end
end
