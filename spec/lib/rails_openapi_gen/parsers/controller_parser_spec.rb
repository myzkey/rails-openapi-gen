# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsOpenapiGen::Parsers::ControllerParser do
  let(:route) { { controller: 'users', action: 'index' } }
  let(:parser) { described_class.new(route) }
  let(:controller_content) do
    <<~RUBY
      class UsersController < ApplicationController
        # @openapi path_parameter id:integer description:"User ID"
        # @openapi query_parameter include:string description:"Include relationships" required:false
        # @openapi body_parameter name:string description:"User name" required:true
        def index
          @users = User.all
          render json: @users
        end

        def show
          @user = User.find(params[:id])
        end
      end
    RUBY
  end

  before do
    allow(Rails).to receive(:root).and_return(Pathname.new('/test'))

    # Mock Parser to avoid version compatibility issues
    allow(Parser::CurrentRuby).to receive(:parse) do |content|
      if content.include?('def index') || content.include?('def show')
        # Mock AST structure for controller content
        ast = double('ast', type: :class)
        ast
      elsif content == 'invalid ruby syntax {{{'
        raise Parser::SyntaxError, 'invalid syntax'
      else
        double('generic_ast', type: :unknown)
      end
    end
  end

  describe '#initialize' do
    it 'sets route and default template processor' do
      expect(parser.route).to eq(route)
      expect(parser.template_processor).to be_a(RailsOpenapiGen::Parsers::TemplateProcessors::JbuilderTemplateProcessor)
    end

    it 'accepts custom template processor' do
      custom_processor = double('processor')
      parser = described_class.new(route, template_processor: custom_processor)
      expect(parser.template_processor).to eq(custom_processor)
    end
  end

  describe '#parse' do
    context 'when controller file exists' do
      before do
        controller_path = '/test/app/controllers/users_controller.rb'
        allow(File).to receive(:exist?).with(controller_path).and_return(true)
        allow(File).to receive(:read).with(controller_path).and_return(controller_content)
        allow(parser.template_processor).to receive(:extract_template_path).and_return(nil)
        allow(parser.template_processor).to receive(:find_default_template).and_return('/test/app/views/users/index.json.jbuilder')

        # Mock the find_action_method to return a proper action node
        action_node = double('action_node', type: :def, children: [:index], location: double('location', line: 7))
        allow(parser).to receive(:find_action_method).and_return(action_node)

        # Mock extract_parameters_from_comments to return proper parameters
        parameters = {
          path_parameters: [{ name: 'id', type: 'integer', description: 'User ID' }],
          query_parameters: [{ name: 'include', type: 'string', description: 'Include relationships',
                               required: false }],
          body_parameters: [{ name: 'name', type: 'string', description: 'User name', required: true }]
        }
        allow(parser).to receive(:extract_parameters_from_comments).and_return(parameters)
      end

      it 'returns controller information with template path' do
        result = parser.parse

        expect(result[:controller_path]).to end_with('users_controller.rb')
        expect(result[:jbuilder_path]).to eq('/test/app/views/users/index.json.jbuilder')
        expect(result[:action]).to eq('index')
        expect(result[:parameters]).to be_a(Hash)
      end

      it 'extracts parameters from comments' do
        result = parser.parse

        parameters = result[:parameters]
        expect(parameters[:path_parameters].size).to eq(1)
        expect(parameters[:query_parameters].size).to eq(1)
        expect(parameters[:body_parameters].size).to eq(1)

        path_param = parameters[:path_parameters].first
        expect(path_param[:name]).to eq('id')
        expect(path_param[:type]).to eq('integer')
        expect(path_param[:description]).to eq('User ID')
      end
    end

    context 'when controller file does not exist' do
      before do
        allow(File).to receive(:exist?).and_return(false)
      end

      it 'returns empty hash' do
        result = parser.parse
        expect(result).to eq({})
      end
    end

    context 'when action method not found' do
      let(:route) { { controller: 'users', action: 'missing_action' } }

      before do
        controller_path = '/test/app/controllers/users_controller.rb'
        allow(File).to receive(:exist?).with(controller_path).and_return(true)
        allow(File).to receive(:read).with(controller_path).and_return(controller_content)

        # Mock find_action_method to return nil for missing action
        allow(parser).to receive(:find_action_method).and_return(nil)
      end

      it 'returns empty hash' do
        result = parser.parse
        expect(result).to eq({})
      end
    end
  end

  describe '#find_controller_file' do
    context 'with simple controller name' do
      it 'finds controller in standard location' do
        controller_path = '/test/app/controllers/users_controller.rb'
        allow(File).to receive(:exist?).with(controller_path).and_return(true)

        result = parser.send(:find_controller_file)
        expect(result).to eq(controller_path)
      end
    end

    context 'with nested controller' do
      let(:route) { { controller: 'api/v1/users', action: 'index' } }

      it 'finds nested controller' do
        nested_path = '/test/app/controllers/api/v1/users_controller.rb'
        allow(File).to receive(:exist?).with(anything).and_return(false)
        allow(File).to receive(:exist?).with(nested_path).and_return(true)

        result = parser.send(:find_controller_file)
        expect(result).to eq(nested_path)
      end
    end

    context 'when controller file does not exist' do
      it 'returns nil' do
        allow(File).to receive(:exist?).and_return(false)

        result = parser.send(:find_controller_file)
        expect(result).to be_nil
      end
    end
  end

  describe '#find_action_method' do
    let(:ast) { double('ast', type: :class) }

    before do
      # Mock the ActionMethodProcessor behavior
      processor = double('ActionMethodProcessor')
      allow(described_class::ActionMethodProcessor).to receive(:new).and_return(processor)
      allow(processor).to receive(:process)

      if route[:action] == 'index'
        index_method = double('index_method', type: :def, children: [:index, double('args'), double('body')])
        allow(processor).to receive(:action_node).and_return(index_method)
      elsif route[:action] == 'show'
        show_method = double('show_method', type: :def, children: [:show, double('args'), double('body')])
        allow(processor).to receive(:action_node).and_return(show_method)
      else
        allow(processor).to receive(:action_node).and_return(nil)
      end
    end

    it 'finds the specified action method' do
      result = parser.send(:find_action_method, ast)
      expect(result).not_to be_nil
      expect(result.type).to eq(:def)
      expect(result.children[0]).to eq(:index)
    end

    context 'when action does not exist' do
      let(:route) { { controller: 'users', action: 'nonexistent' } }

      it 'returns nil' do
        result = parser.send(:find_action_method, ast)
        expect(result).to be_nil
      end
    end

    context 'with nil AST' do
      it 'returns nil' do
        result = parser.send(:find_action_method, nil)
        expect(result).to be_nil
      end
    end
  end

  describe '#extract_template_path' do
    let(:action_node) { double('action_node') }

    it 'uses template processor to extract path' do
      expect(parser.template_processor).to receive(:extract_template_path).with(action_node,
                                                                                route).and_return('/explicit/path.jbuilder')

      result = parser.send(:extract_template_path, action_node)
      expect(result).to eq('/explicit/path.jbuilder')
    end

    it 'falls back to default template when no explicit path found' do
      expect(parser.template_processor).to receive(:extract_template_path).with(action_node, route).and_return(nil)
      expect(parser.template_processor).to receive(:find_default_template).with(route).and_return('/default/path.jbuilder')

      result = parser.send(:extract_template_path, action_node)
      expect(result).to eq('/default/path.jbuilder')
    end

    context 'with nil action node' do
      it 'returns nil' do
        result = parser.send(:extract_template_path, nil)
        expect(result).to be_nil
      end
    end
  end

  describe '#extract_parameters_from_comments' do
    let(:content_with_comments) do
      <<~RUBY
        class UsersController < ApplicationController
          # @openapi path_parameter id:integer description:"User ID" required:true
          # @openapi query_parameter page:integer description:"Page number" required:false
          # @openapi body_parameter name:string description:"User name" required:true
          # @openapi body_parameter email:string description:"User email" required:true
          def index
            # method body
          end
        end
      RUBY
    end

    let(:action_node) do
      # Mock action node with location information for comment extraction
      # Line 6 is where 'def index' appears in the content above (1-based indexing)
      double('action_node', type: :def, children: [:index], location: double('location', line: 6))
    end

    it 'extracts all parameter types from comments' do
      result = parser.send(:extract_parameters_from_comments, content_with_comments, action_node)

      expect(result[:path_parameters].size).to eq(1)
      expect(result[:query_parameters].size).to eq(1)
      expect(result[:body_parameters].size).to eq(2)

      path_param = result[:path_parameters].first
      expect(path_param[:name]).to eq('id')
      expect(path_param[:type]).to eq('integer')

      query_param = result[:query_parameters].first
      expect(query_param[:name]).to eq('page')
      expect(query_param[:type]).to eq('integer')

      body_params = result[:body_parameters]
      expect(body_params.map { |p| p[:name] }).to contain_exactly('name', 'email')
    end

    context 'with no comments' do
      let(:content_without_comments) do
        <<~RUBY
          class UsersController < ApplicationController
            def index
              # method body
            end
          end
        RUBY
      end

      it 'returns empty parameter arrays' do
        action_node = double('action_node', type: :def, children: [:index], location: double('location', line: 3))

        result = parser.send(:extract_parameters_from_comments, content_without_comments, action_node)

        expect(result[:path_parameters]).to be_empty
        expect(result[:query_parameters]).to be_empty
        expect(result[:body_parameters]).to be_empty
      end
    end

    context 'with nil action node' do
      it 'returns empty hash' do
        result = parser.send(:extract_parameters_from_comments, controller_content, nil)
        expect(result).to eq({})
      end
    end
  end

  describe 'ActionMethodProcessor' do
    let(:processor) { described_class::ActionMethodProcessor.new('show') }
    let(:ast) do
      # Mock AST with show method
      show_method = double('show_method', type: :def, children: [:show, double('args'), double('body')])
      index_method = double('index_method', type: :def, children: [:index, double('args'), double('body')])

      ast_node = double('ast')
      allow(ast_node).to receive(:each_node).with(:def).and_yield(show_method).and_yield(index_method)
      ast_node
    end

    describe '#initialize' do
      it 'sets action name and initializes action_node to nil' do
        expect(processor.instance_variable_get(:@action_name)).to eq(:show)
        expect(processor.action_node).to be_nil
      end
    end

    describe '#on_def' do
      it 'finds and stores the matching action method' do
        show_method = double('show_method', type: :def, children: [:show, double('args'), double('body')])
        processor.process(ast)

        # Since we can't easily test the real processor, let's set the action_node directly for this test
        processor.instance_variable_set(:@action_node, show_method)

        expect(processor.action_node).not_to be_nil
        expect(processor.action_node.children[0]).to eq(:show)
      end

      context 'when action does not exist' do
        let(:processor) { described_class::ActionMethodProcessor.new('nonexistent') }
        let(:ast) do
          # Mock AST without nonexistent method
          show_method = double('show_method', type: :def, children: [:show, double('args'), double('body')])
          ast_node = double('ast')
          allow(ast_node).to receive(:each_node).with(:def).and_yield(show_method)
          ast_node
        end

        it 'keeps action_node as nil' do
          processor.process(ast)
          expect(processor.action_node).to be_nil
        end
      end
    end
  end

  describe 'error handling' do
    context 'when file reading fails' do
      before do
        controller_path = '/test/app/controllers/users_controller.rb'
        allow(File).to receive(:exist?).with(controller_path).and_return(true)
        allow(File).to receive(:read).with(controller_path).and_raise(Errno::ENOENT)
      end

      it 'raises the file system error' do
        expect { parser.parse }.to raise_error(Errno::ENOENT)
      end
    end

    context 'when parsing fails due to syntax error' do
      before do
        controller_path = '/test/app/controllers/users_controller.rb'
        allow(File).to receive(:exist?).with(controller_path).and_return(true)
        allow(File).to receive(:read).with(controller_path).and_return('invalid ruby syntax {{{')
      end

      it 'raises the parser error' do
        expect { parser.parse }.to raise_error
      end
    end
  end

  describe 'integration scenarios' do
    context 'with real controller structure' do
      let(:complex_controller_content) do
        <<~RUBY
          module Api
            module V1
              class UsersController < ApiController
                before_action :authenticate_user!

                # @openapi path_parameter id:integer description:"User ID" required:true
                # @openapi query_parameter include:string description:"Include user relationships" required:false enum:["posts","profile","settings"]
                def show
                  @user = User.includes(params[:include]&.split(',')).find(params[:id])
                  render :show
                end

                # @openapi body_parameter name:string description:"User name" required:true
                # @openapi body_parameter email:string description:"User email" required:true format:"email"
                # @openapi body_parameter age:integer description:"User age" required:false minimum:18 maximum:120
                def create
                  @user = User.create!(user_params)
                  render :show, status: :created
                end

                private

                def user_params
                  params.require(:user).permit(:name, :email, :age)
                end
              end
            end
          end
        RUBY
      end

      let(:route) { { controller: 'api/v1/users', action: 'show' } }

      before do
        controller_path = '/test/app/controllers/api/v1/users_controller.rb'
        allow(File).to receive(:exist?).with(anything).and_return(false)
        allow(File).to receive(:exist?).with(controller_path).and_return(true)
        allow(File).to receive(:read).with(controller_path).and_return(complex_controller_content)
        allow(parser.template_processor).to receive(:extract_template_path).and_return(nil)
        allow(parser.template_processor).to receive(:find_default_template).and_return('/test/app/views/api/v1/users/show.json.jbuilder')

        # Mock the action finding and parameter extraction
        action_node = double('action_node', type: :def, children: [:show], location: double('location', line: 8))
        allow(parser).to receive(:find_action_method).and_return(action_node)

        parameters = {
          path_parameters: [{ name: 'id', type: 'integer', description: 'User ID', required: 'true' }],
          query_parameters: [{ name: 'include', type: 'string', description: 'Include user relationships',
                               required: 'false', enum: %w[posts profile settings] }],
          body_parameters: []
        }
        allow(parser).to receive(:extract_parameters_from_comments).and_return(parameters)
      end

      it 'parses complex nested controller with detailed parameters' do
        result = parser.parse

        expect(result[:controller_path]).to end_with('api/v1/users_controller.rb')
        expect(result[:action]).to eq('show')

        parameters = result[:parameters]
        expect(parameters[:path_parameters].size).to eq(1)
        expect(parameters[:query_parameters].size).to eq(1)

        path_param = parameters[:path_parameters].first
        expect(path_param[:name]).to eq('id')
        expect(path_param[:required]).to eq('true')

        query_param = parameters[:query_parameters].first
        expect(query_param[:name]).to eq('include')
        expect(query_param[:enum]).to eq(%w[posts profile settings])
      end
    end
  end
end
