module RecipeQueryHelper
  extend ActiveSupport::Concern

  def process_recipes
    @filtered_recipes = Recipe.api_query(filtered_recipe_params)
    @count = @filtered_recipes.count
    @recipes = @filtered_recipes.offset(offset).limit(page_length).order(:name => :asc)
    @show_next = more_pages_count < @count
    @page = page
  end

  private
  def filtered_recipe_params
    if params.has_key?(:filtered_recipe)
      params[:filtered_recipe].permit!
    else
      params
    end
  end
end
