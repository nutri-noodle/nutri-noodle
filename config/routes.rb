Rails.application.routes.draw do
  devise_for :users
  namespace :api do
    resources :recipes, only: [:index, :show]
  end
  resources :recipes, only: [:index, :show] do
    collection do
      post :filter
    end
  end
  resources :score_foods, only: [:index]
  resources :recommendations, only: [:index]
  # get 'nutrition_advice', controller: 'nutrition_advice', action: "index"

  resources :nutrition_advice, controller: :chats, as: :chat, only: %i[index create show] do
    resources :messages, only: %i[create]
  end

  get 'home', controller: 'home', action: "index"
  root 'home#index'
  # mount Sidekiq::Web => '/sidekiq'
end
