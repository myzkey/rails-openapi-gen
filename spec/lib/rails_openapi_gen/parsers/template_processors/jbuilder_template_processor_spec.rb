# frozen_string_literal: true

require 'spec_helper'

RSpec.describe RailsOpenapiGen::Parsers::TemplateProcessors::JbuilderTemplateProcessor do
  # Skip tests that require actual file parsing due to Parser version compatibility issues
  before(:all) do
    if RUBY_VERSION < '3.1.7'
      skip "Skipping template processor tests due to Parser gem version compatibility issues"
    end
  end
  let(:controller) { 'users' }
  let(:action) { 'index' }
  let(:processor) { described_class.new(controller, action) }
  let(:route) { { controller: controller, action: action } }

  before do
    allow(Rails).to receive(:root).and_return(Pathname.new('/test'))
  end

  describe '#initialize' do
    it 'sets controller and action' do
      expect(processor.instance_variable_get(:@controller)).to eq(controller)
      expect(processor.instance_variable_get(:@action)).to eq(action)
    end
  end

  describe '#extract_template_path' do
    context 'with render call without arguments' do
      let(:controller_content) do
        <<~RUBY
          def index
            @users = User.all
            render
          end
        RUBY
      end

      it 'returns default jbuilder path' do
        ast = Parser::CurrentRuby.parse(controller_content)
        action_node = ast.children[2]  # Get method body, not method name

        result = processor.extract_template_path(action_node, route)
        expect(result.to_s).to end_with('app/views/users/index.json.jbuilder')
      end
    end

    context 'with render call with json option' do
      let(:controller_content) do
        <<~RUBY
          def index
            @users = User.all
            render json: @users
          end
        RUBY
      end

      it 'returns default jbuilder path' do
        ast = Parser::CurrentRuby.parse(controller_content)
        action_node = ast.children[2]  # Get method body, not method name

        result = processor.extract_template_path(action_node, route)
        expect(result.to_s).to end_with('app/views/users/index.json.jbuilder')
      end
    end

    context 'with render call with specific template' do
      let(:controller_content) do
        <<~RUBY
          def index
            @users = User.all
            render 'custom_template'
          end
        RUBY
      end

      it 'returns custom template path' do
        ast = Parser::CurrentRuby.parse(controller_content)
        action_node = ast.children[2]  # Get method body, not method name

        result = processor.extract_template_path(action_node, route)
        expect(result.to_s).to end_with('app/views/users/custom_template.json.jbuilder')
      end
    end

    context 'with render call with template option' do
      let(:controller_content) do
        <<~RUBY
          def index
            @users = User.all
            render template: 'shared/users'
          end
        RUBY
      end

      it 'returns specified template path' do
        ast = Parser::CurrentRuby.parse(controller_content)
        action_node = ast.children[2]  # Get method body, not method name

        result = processor.extract_template_path(action_node, route)
        expect(result.to_s).to end_with('app/views/shared/users.json.jbuilder')
      end
    end

    context 'with render call with template, formats and handlers' do
      let(:controller_content) do
        <<~RUBY
          def index
            @users = User.all
            render template: 'api/users/list', formats: :xml, handlers: :builder
          end
        RUBY
      end

      it 'returns template path with custom format and handler' do
        ast = Parser::CurrentRuby.parse(controller_content)
        action_node = ast.children[2]  # Get method body, not method name

        result = processor.extract_template_path(action_node, route)
        expect(result.to_s).to end_with('app/views/api/users/list.xml.builder')
      end
    end

    context 'with symbol template name' do
      let(:controller_content) do
        <<~RUBY
          def index
            @users = User.all
            render :show
          end
        RUBY
      end

      it 'returns template path from symbol' do
        ast = Parser::CurrentRuby.parse(controller_content)
        action_node = ast.children[2]  # Get method body, not method name

        result = processor.extract_template_path(action_node, route)
        expect(result.to_s).to end_with('app/views/users/show.json.jbuilder')
      end
    end

    context 'with no render call' do
      let(:controller_content) do
        <<~RUBY
          def index
            @users = User.all
            # No render call
          end
        RUBY
      end

      it 'returns nil' do
        ast = Parser::CurrentRuby.parse(controller_content)
        action_node = ast.children[2]  # Get method body, not method name

        result = processor.extract_template_path(action_node, route)
        expect(result).to be_nil
      end
    end

    context 'with nil action node' do
      it 'returns nil' do
        result = processor.extract_template_path(nil, route)
        expect(result).to be_nil
      end
    end
  end

  describe '#find_default_template' do
    context 'when default template exists' do
      it 'returns template path' do
        template_path = '/test/app/views/users/index.json.jbuilder'
        allow(File).to receive(:exist?).with(Pathname.new(template_path)).and_return(true)

        result = processor.find_default_template(route)
        expect(result).to eq(template_path)
      end
    end

    context 'when default template does not exist' do
      it 'returns nil' do
        allow(File).to receive(:exist?).and_return(false)

        result = processor.find_default_template(route)
        expect(result).to be_nil
      end
    end

    context 'with nested controller' do
      let(:route) { { controller: 'api/v1/users', action: 'show' } }

      it 'finds nested template path' do
        template_path = '/test/app/views/api/v1/users/show.json.jbuilder'
        allow(File).to receive(:exist?).with(Pathname.new(template_path)).and_return(true)

        result = processor.find_default_template(route)
        expect(result).to eq(template_path)
      end
    end
  end

  describe 'JbuilderPathProcessor' do
    let(:path_processor) { described_class::JbuilderPathProcessor.new(controller, action) }

    describe '#initialize' do
      it 'sets controller, action and initializes jbuilder_path' do
        expect(path_processor.instance_variable_get(:@controller)).to eq(controller)
        expect(path_processor.instance_variable_get(:@action)).to eq(action)
        expect(path_processor.jbuilder_path).to be_nil
      end
    end

    describe '#on_send' do
      context 'with simple render call' do
        let(:ast) { Parser::CurrentRuby.parse('render') }

        it 'sets default jbuilder path' do
          path_processor.process(ast)
          expect(path_processor.jbuilder_path.to_s).to end_with('app/views/users/index.json.jbuilder')
        end
      end

      context 'with render json call' do
        let(:ast) { Parser::CurrentRuby.parse('render json: @users') }

        it 'sets default jbuilder path' do
          path_processor.process(ast)
          expect(path_processor.jbuilder_path.to_s).to end_with('app/views/users/index.json.jbuilder')
        end
      end

      context 'with non-render method calls' do
        let(:ast) { Parser::CurrentRuby.parse('redirect_to users_path') }

        it 'does not set jbuilder_path' do
          path_processor.process(ast)
          expect(path_processor.jbuilder_path).to be_nil
        end
      end
    end

    describe '#render_call?' do
      it 'identifies render calls correctly' do
        render_node = Parser::CurrentRuby.parse('render')
        redirect_node = Parser::CurrentRuby.parse('redirect_to users_path')

        expect(path_processor.send(:render_call?, render_node)).to be true
        expect(path_processor.send(:render_call?, redirect_node)).to be false
      end
    end

    describe '#extract_render_target' do
      context 'with empty arguments' do
        let(:render_node) { Parser::CurrentRuby.parse('render') }

        it 'sets default jbuilder path' do
          path_processor.send(:extract_render_target, render_node)
          expect(path_processor.jbuilder_path.to_s).to end_with('app/views/users/index.json.jbuilder')
        end
      end

      context 'with string argument' do
        let(:render_node) { Parser::CurrentRuby.parse("render 'show'") }

        it 'sets custom template path' do
          path_processor.send(:extract_render_target, render_node)
          expect(path_processor.jbuilder_path.to_s).to end_with('app/views/users/show.json.jbuilder')
        end
      end

      context 'with hash options' do
        let(:render_node) { Parser::CurrentRuby.parse("render template: 'shared/user'") }

        it 'parses hash options' do
          path_processor.send(:extract_render_target, render_node)
          expect(path_processor.jbuilder_path.to_s).to end_with('app/views/shared/user.json.jbuilder')
        end
      end
    end

    describe '#parse_render_options' do
      context 'with json option' do
        let(:hash_node) { Parser::CurrentRuby.parse("{ json: @users }") }

        it 'sets default jbuilder path for json render' do
          path_processor.send(:parse_render_options, hash_node)
          expect(path_processor.jbuilder_path.to_s).to end_with('app/views/users/index.json.jbuilder')
        end
      end

      context 'with template option' do
        let(:hash_node) { Parser::CurrentRuby.parse("{ template: 'api/users/list' }") }

        it 'builds template path from options' do
          path_processor.send(:parse_render_options, hash_node)
          expect(path_processor.jbuilder_path.to_s).to end_with('app/views/api/users/list.json.jbuilder')
        end
      end
    end

    describe '#extract_render_hash_options' do
      let(:hash_node) { Parser::CurrentRuby.parse("{ template: 'shared/user', formats: :xml, status: :ok }") }

      it 'extracts all hash options' do
        result = path_processor.send(:extract_render_hash_options, hash_node)
        
        expect(result[:template]).to eq('shared/user')
        expect(result[:formats]).to eq(:xml)
        expect(result[:status]).to eq(:ok)
      end
    end

    describe '#extract_node_value' do
      it 'extracts values from different node types' do
        str_node = Parser::CurrentRuby.parse('"test"')
        sym_node = Parser::CurrentRuby.parse(':test')
        true_node = Parser::CurrentRuby.parse('true')
        false_node = Parser::CurrentRuby.parse('false')

        expect(path_processor.send(:extract_node_value, str_node)).to eq('test')
        expect(path_processor.send(:extract_node_value, sym_node)).to eq(:test)
        expect(path_processor.send(:extract_node_value, true_node)).to be true
        expect(path_processor.send(:extract_node_value, false_node)).to be false
      end
    end

    describe '#build_template_path' do
      it 'builds template path with format and handler' do
        result = path_processor.send(:build_template_path, 'users/show', :json, :jbuilder)
        expect(result).to eq('users/show.json.jbuilder')
      end

      it 'handles string formats and handlers' do
        result = path_processor.send(:build_template_path, 'api/users', 'xml', 'builder')
        expect(result).to eq('api/users.xml.builder')
      end

      it 'uses defaults for nil values' do
        result = path_processor.send(:build_template_path, 'users/index', nil, nil)
        expect(result).to eq('users/index.json.jbuilder')
      end

      it 'handles nested paths correctly' do
        result = path_processor.send(:build_template_path, 'api/v1/users/show', :json, :jbuilder)
        expect(result).to eq("api#{File::SEPARATOR}v1#{File::SEPARATOR}users#{File::SEPARATOR}show.json.jbuilder")
      end
    end

    describe '#default_jbuilder_path' do
      it 'returns default template path' do
        result = path_processor.send(:default_jbuilder_path)
        expect(result.to_s).to end_with('app/views/users/index.json.jbuilder')
      end
    end
  end

  describe 'complex integration scenarios' do
    context 'with multiple render calls in action' do
      let(:controller_content) do
        <<~RUBY
          def index
            if params[:format] == 'xml'
              render template: 'users/index_xml', formats: :xml
            else
              render json: @users
            end
          end
        RUBY
      end

      it 'finds the first render call' do
        ast = Parser::CurrentRuby.parse(controller_content)
        action_node = ast.children[2]  # Get method body, not method name

        result = processor.extract_template_path(action_node, route)
        expect(result.to_s).to end_with('app/views/users/index_xml.xml.jbuilder')
      end
    end

    context 'with conditional render' do
      let(:controller_content) do
        <<~RUBY
          def show
            @user = User.find(params[:id])
            render :show if @user.present?
          end
        RUBY
      end

      it 'extracts template from conditional render' do
        ast = Parser::CurrentRuby.parse(controller_content)
        action_node = ast.children[2]  # Get method body, not method name

        result = processor.extract_template_path(action_node, route)
        expect(result.to_s).to end_with('app/views/users/show.json.jbuilder')
      end
    end

    context 'with render in rescue block' do
      let(:controller_content) do
        <<~RUBY
          def show
            @user = User.find(params[:id])
          rescue ActiveRecord::RecordNotFound
            render template: 'errors/not_found', status: :not_found
          end
        RUBY
      end

      it 'finds render call in rescue block' do
        ast = Parser::CurrentRuby.parse(controller_content)
        action_node = ast.children[2]  # Get method body, not method name

        result = processor.extract_template_path(action_node, route)
        expect(result.to_s).to end_with('app/views/errors/not_found.json.jbuilder')
      end
    end
  end

  describe 'edge cases' do
    context 'with malformed render calls' do
      let(:controller_content) do
        <<~RUBY
          def index
            render if false
            some_other_method
          end
        RUBY
      end

      it 'handles malformed render gracefully' do
        ast = Parser::CurrentRuby.parse(controller_content)
        action_node = ast.children[2]  # Get method body, not method name

        expect { processor.extract_template_path(action_node, route) }.not_to raise_error
      end
    end

    context 'with deeply nested controller path' do
      let(:route) { { controller: 'admin/api/v2/deeply/nested/users', action: 'show' } }

      it 'handles deeply nested paths' do
        template_path = '/test/app/views/admin/api/v2/deeply/nested/users/show.json.jbuilder'
        allow(File).to receive(:exist?).with(Pathname.new(template_path)).and_return(true)

        result = processor.find_default_template(route)
        expect(result).to eq(template_path)
      end
    end
  end
end