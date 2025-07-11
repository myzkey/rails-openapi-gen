Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # API routes for testing rails-openapi-gen
  namespace :api do
    get 'dashboard', to: 'dashboard#index'

    resources :users, only: [:index, :show, :create, :update, :destroy] do
      resources :posts, only: [:index, :show, :create]
      resources :orders, only: [:index]
      member do
        patch :activate
        patch :deactivate
      end
    end

    resources :posts, only: [:index, :show] do
      resources :comments, only: [:index, :create]

      # Custom actions with explicit template rendering
      collection do
        get :featured  # Uses explicit template: "api/v1/posts/featured_list"
        get :archive   # Uses shared template: "shared/post_list"
      end
    end

    # Authentication routes
    namespace :auth do
      post :login
      post :register
      delete :logout
    end
    # Orders routes
    resources :orders, only: [:show]
  end

  # Admin routes
  # namespace :admin do
  #   resources :users, only: [:index, :show, :destroy]
  #   resources :reports, only: [:index, :show]
  # end

  # Defines the root path route ("/")
  # root "posts#index"
end
