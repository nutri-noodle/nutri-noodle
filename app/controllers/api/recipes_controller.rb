module Api
  class RecipesController
    include PagedQueryHelper

    api :GET, '/api/recipes', "Searches and browses public recipes"
    param :meal_times,              ["Breakfast", "AM Snack", "Lunch", "Midday Snack", "Dinner", "PM Snack"], :required => false, :desc => "List of meal times to include - recipes matching any values in param will be included in the response."
    param :meal_types,              ["Make-ahead", "Dessert", "Family-friendly", "Easy", "Side Dish", "Condiment/Dressing", "Soup or Stew", "Salad", "One-pot", "For One or Two", "Slow Cook", "Appetizer", "Bread or Pastry", "Pack-N-Go", "Main Dish", "Budget Friendly"], :required => false, :desc => "List of meal types to include - recipes matching all values in param will be included in the response."
    param :dietary_preferences,     ["Vegan", "Vegetarian", "Kosher", "Keto", "Paleo"], :required => false, :desc => "List of dietary_preferences to include - recipes matching all values in param will be included in the response."
    param :main_ingredients,        ["Other Grains", "Nuts/Seeds", "Fish", "Fruit", "Starchy Vegetables", "Rice", "Beans/Peas", "Other Seafood", "Non-starchy Vegetables", "Bread/Pizza", "Beef", "Turkey", "Cheese", "Milk/Yogurt", "Pork", "Meat Alternative", "Eggs", "Pasta", "Other Meat", "Chicken"], :required => false,  :desc => "List of main ingredients to include - recipes matching all values in param will be included in the response."
    param :allergens,               ["Tree Nuts", "Fish", "Peanuts", "Soy", "Shellfish", "Eggs", "Gluten", "Wheat", "Milk"], :required => false, :desc => "List of allergens to exclude - recipes matching any values in param will be excluded in the response.  Defaults to excluding no allergens."
    param :cooking_time,            ["More than an hour", "30 minutes or less", "An Hour or less", "Quick"], :required => false, :desc => "List of speed categories to include - recipes matching all values in param will be included in the response."
    param :any_meal_types,          ["Make-ahead", "Dessert", "Family-friendly", "Easy", "Side Dish", "Condiment/Dressing", "Soup or Stew", "Salad", "One-pot", "For One or Two", "Slow Cook", "Appetizer", "Bread or Pastry", "Pack-N-Go", "Main Dish", "Budget Friendly"], :required => false, :desc => "List of meal types to include - recipes matching any values in param will be included in the response."
    param :any_dietary_preferences, ["Vegan", "Vegetarian", "Kosher", "Keto", "Paleo"], :required => false, :desc => "List of dietary_preferences to include - recipes matching any values in param will be included in the response."
    param :any_main_ingredients,    ["Other Grains", "Nuts/Seeds", "Fish", "Fruit", "Starchy Vegetables", "Rice", "Beans/Peas", "Other Seafood", "Non-starchy Vegetables", "Bread/Pizza", "Beef", "Turkey", "Cheese", "Milk/Yogurt", "Pork", "Meat Alternative", "Eggs", "Pasta", "Other Meat", "Chicken"], :required => false,  :desc => "List of main ingredients to include - recipes matching any values in param will be included in the response."
    param :any_cooking_time,        ["More than an hour", "30 minutes or less", "An Hour or less", "Quick"], :required => false, :desc => "List of speed categories to include.  Each entry is the id of an allergen.  Defaults to excluding no allergens."
    param :with_instructions,  :boolean, :required => false, :desc => "Does the recipe contain Instructions - Defaults to including recipes with and without instructions"
    param :with_images,        :boolean, :required => false, :desc => "Does the recipe have an Image - Defaults to including recipes with and without image"
    param :source,              String,  :required => false, :desc => "Specif what source the food came from, defaults to 'Public'"
    param :profile,             Integer, :required => false, :desc => "Id of the matching Profile for the foods returned"
    param :page,                Integer, :required => false, :desc => "Which page of the results to jump to.  Defaults to the first page.  Pages are 1 indexed"
    param :page_length,         Integer, :required => false, :desc => "How many results to include on each page.  Defaults to 20"
    param :search,              String,  :required => false, :desc => "Include recipes that have ingredients names or recipe names that fuzzy match this value.  Defaults to including all recipes"
    param :exclude,             String,  :required => false, :desc => "Exclude recipes that have ingredients names or recipe names that fuzzy match this value"

    def index
      process_recipes
    end

    def count
      @count
    end
    alias_method :total, :count

    def total_pages
      (count / page_length.to_f).ceil
    end

    helper_method :total_pages, :total
  end
end
