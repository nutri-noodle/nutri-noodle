Rails.application.routes.draw do
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
  get 'nutrition_advice', controller: 'nutrition_advice', action: "index"

  get 'home', controller: 'home', action: "index"
  root 'home#index'
end
