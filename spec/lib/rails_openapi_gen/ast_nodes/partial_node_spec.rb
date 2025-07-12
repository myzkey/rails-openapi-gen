require 'spec_helper'

RSpec.describe RailsOpenapiGen::AstNodes::PartialNode do
  let(:comment_data) do
    RailsOpenapiGen::AstNodes::CommentData.new(
      type: 'object',
      description: 'User partial'
    )
  end

  describe '#initialize' do
    it 'initializes with all attributes' do
      node = described_class.new(
        property_name: 'user_info',
        partial_path: 'api/users/user',
        local_variables: { user: 'current_user', show_email: true },
        comment_data: comment_data,
        is_conditional: true
      )

      expect(node.property_name).to eq('user_info')
      expect(node.partial_path).to eq('api/users/user')
      expect(node.local_variables).to eq({ user: 'current_user', show_email: true })
      expect(node.comment_data).to eq(comment_data)
      expect(node.is_conditional).to be true
    end

    it 'sets default values' do
      node = described_class.new(
        partial_path: 'test/partial'
      )

      expect(node.property_name).to be_nil
      expect(node.partial_path).to eq('test/partial')
      expect(node.local_variables).to eq({})
      expect(node.comment_data).to be_a(RailsOpenapiGen::AstNodes::CommentData)
      expect(node.is_conditional).to be false
    end

    it 'requires partial_path' do
      expect {
        described_class.new
      }.to raise_error(ArgumentError, /partial_path/)
    end
  end

  describe '#required?' do
    context 'when not conditional and comment_data.required? is true' do
      let(:node) do
        described_class.new(
          property_name: 'user_info',
          partial_path: 'api/users/user',
          comment_data: RailsOpenapiGen::AstNodes::CommentData.new(required: true),
          is_conditional: false
        )
      end

      it 'returns true' do
        expect(node.required?).to be true
      end
    end

    context 'when conditional' do
      let(:node) do
        described_class.new(
          property_name: 'user_info',
          partial_path: 'api/users/user',
          comment_data: RailsOpenapiGen::AstNodes::CommentData.new(required: true),
          is_conditional: true
        )
      end

      it 'returns false' do
        expect(node.required?).to be false
      end
    end

    context 'when comment_data.required? is false' do
      let(:node) do
        described_class.new(
          property_name: 'user_info',
          partial_path: 'api/users/user',
          comment_data: RailsOpenapiGen::AstNodes::CommentData.new(required: false),
          is_conditional: false
        )
      end

      it 'returns false' do
        expect(node.required?).to be false
      end
    end
  end

  describe '#optional?' do
    let(:node) do
      described_class.new(
        property_name: 'test',
        partial_path: 'test/path'
      )
    end

    it 'returns opposite of required?' do
      allow(node).to receive(:required?).and_return(true)
      expect(node.optional?).to be false

      allow(node).to receive(:required?).and_return(false)
      expect(node.optional?).to be true
    end
  end

  describe '#description' do
    it 'returns description from comment_data' do
      node = described_class.new(
        property_name: 'user_info',
        partial_path: 'api/users/user',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(description: 'User information')
      )

      expect(node.description).to eq('User information')
    end

    it 'returns nil when no description' do
      node = described_class.new(
        property_name: 'test',
        partial_path: 'test/path',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new
      )

      expect(node.description).to be_nil
    end
  end

  describe '#resolve_path' do
    it 'returns the partial path when no base path' do
      node = described_class.new(
        partial_path: 'api/users/user'
      )

      expect(node.resolve_path).to eq('api/users/user.json.jbuilder')
    end

    it 'returns absolute path when partial starts with /' do
      node = described_class.new(
        partial_path: '/absolute/path/to/partial'
      )

      expect(node.resolve_path).to eq('/absolute/path/to/partial')
    end

    it 'resolves relative to base path when provided' do
      node = described_class.new(
        partial_path: 'user'
      )

      expect(node.resolve_path('app/views/api/posts/show.json.jbuilder')).to eq('app/views/api/posts/user.json.jbuilder')
    end
  end

  describe '#to_h' do
    let(:node) do
      described_class.new(
        property_name: 'user_profile',
        partial_path: 'api/users/profile',
        local_variables: { user: 'current_user', include_private: false },
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'object',
          description: 'User profile information'
        ),
        is_conditional: true
      )
    end

    it 'returns hash representation' do
      hash = node.to_h

      expect(hash).to include(
        :property_name,
        :partial_path,
        :local_variables,
        :comment_data,
        :is_conditional,
        :required,
        :description
      )

      expect(hash[:property_name]).to eq('user_profile')
      expect(hash[:partial_path]).to eq('api/users/profile')
      expect(hash[:local_variables]).to eq({ user: 'current_user', include_private: false })
      expect(hash[:description]).to eq('User profile information')
      expect(hash[:is_conditional]).to be true
    end

    it 'compacts nil values' do
      node = described_class.new(
        partial_path: 'simple/path',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new
      )

      hash = node.to_h
      expect(hash.keys).to include(:partial_path, :local_variables)
    end
  end

  describe '#accept' do
    let(:node) do
      described_class.new(
        property_name: 'test',
        partial_path: 'test/path'
      )
    end
    let(:visitor) { double('visitor') }

    it 'calls visitor.visit_partial with self' do
      expect(visitor).to receive(:visit_partial).with(node)
      node.accept(visitor)
    end
  end

  describe 'local variables scenarios' do
    it 'handles empty local vars' do
      node = described_class.new(
        partial_path: 'api/users/user'
      )

      expect(node.local_variables).to eq({})
    end

    it 'handles single local var' do
      node = described_class.new(
        partial_path: 'api/users/user',
        local_variables: { user: 'current_user' }
      )

      expect(node.local_variables).to eq({ user: 'current_user' })
    end

    it 'handles multiple local vars' do
      node = described_class.new(
        partial_path: 'api/users/user',
        local_variables: {
          user: 'current_user',
          show_email: true,
          include_address: false,
          format: 'detailed'
        }
      )

      expect(node.local_variables).to eq({
        user: 'current_user',
        show_email: true,
        include_address: false,
        format: 'detailed'
      })
    end

    it 'handles complex local var values' do
      timestamp = Time.now
      node = described_class.new(
        partial_path: 'api/users/user',
        local_variables: {
          user: 'User.find(params[:id])',
          options: { include_private: false, format: :json },
          timestamp: timestamp
        }
      )

      expect(node.local_variables[:user]).to eq('User.find(params[:id])')
      expect(node.local_variables[:options]).to be_a(Hash)
      expect(node.local_variables[:timestamp]).to eq(timestamp)
    end
  end

  describe 'partial path scenarios' do
    it 'handles simple partial paths' do
      node = described_class.new(
        partial_path: 'user'
      )

      expect(node.partial_path).to eq('user')
      expect(node.resolve_path).to eq('user.json.jbuilder')
    end

    it 'handles namespaced partial paths' do
      node = described_class.new(
        partial_path: 'api/v1/users/user'
      )

      expect(node.partial_path).to eq('api/v1/users/user')
      expect(node.resolve_path).to eq('api/v1/users/user.json.jbuilder')
    end

    it 'handles relative partial paths' do
      node = described_class.new(
        partial_path: '../shared/user'
      )

      expect(node.partial_path).to eq('../shared/user')
      expect(node.resolve_path).to eq('../shared/user.json.jbuilder')
    end

    it 'handles absolute partial paths' do
      node = described_class.new(
        partial_path: '/app/views/shared/user'
      )

      expect(node.partial_path).to eq('/app/views/shared/user')
      expect(node.resolve_path).to eq('/app/views/shared/user')
    end
  end

  describe 'conditional partial scenarios' do
    it 'handles conditional required partials' do
      node = described_class.new(
        property_name: 'admin_info',
        partial_path: 'api/admin/user_info',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'object',
          required: true,
          description: 'Admin user information'
        ),
        is_conditional: true
      )

      # Even though comment_data says required: true, conditional partials are not required
      expect(node.required?).to be false
      expect(node.optional?).to be true
      expect(node.is_conditional).to be true
    end

    it 'handles non-conditional partials' do
      node = described_class.new(
        property_name: 'user_info',
        partial_path: 'api/users/user',
        comment_data: RailsOpenapiGen::AstNodes::CommentData.new(
          type: 'object',
          required: true,
          description: 'User information'
        ),
        is_conditional: false
      )

      expect(node.required?).to be true
      expect(node.optional?).to be false
      expect(node.is_conditional).to be false
    end
  end
end