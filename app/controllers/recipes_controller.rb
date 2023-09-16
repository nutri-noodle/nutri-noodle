class RecipesController < ApplicationController
  include PagedQueryHelper
  include RecipeQueryHelper
  before_action :process_recipes, only: [:filter, :index]

  def index
  end

  def filter
  end
end
