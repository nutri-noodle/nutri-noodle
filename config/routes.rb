Rails.application.routes.draw do
  apipie
  devise_for :users
  namespace :api do
    resources :recipes, only: [:index, :show]
  end
  resources :recipes, only: [:index, :show] do
    collection do
      post :filter
    end
  end
  resource :profile, controller: :profile
  resources :score_foods, only: [:index]
  resources :recommendations, only: [:index]
  # get 'nutrition_advice', controller: 'nutrition_advice', action: "index"

  resources :nutrition_advice, controller: :messages, as: :messages, only: %i[index create show]
  delete :nutrition_advice, controller: :messages, action: :destroy, as: :delete_messages

  get 'home', controller: 'home', action: "index"
  get 'shopping_list', controller: 'shopping_list', action: 'show'
  get 'food_hover/:id', controller: 'food_hover', action: 'show'
  root 'home#index'
  # mount Sidekiq::Web => '/sidekiq'
end
