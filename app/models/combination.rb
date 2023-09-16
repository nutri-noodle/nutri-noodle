class Combination < Food

  def combination?
    true
  end

  def self.search_by_name(name)
    where("lower(name)= ? and enabled = true", name.downcase).first
  end

  # combinations scale their serving simply by a scale factor for all the
  # ingredients and ingredients under them
  def shopping_list_breakdown(serving,scale_factor, participant)
    ingredients.inject([]) do |acc, ingredient|
      acc.concat(ingredient.food.shopping_list_breakdown(ingredient, serving.multiplier * scale_factor, participant))
    end
  end
  alias_method :shopping_list_breakdown2, :shopping_list_breakdown

  def recipe_breakdown
    ingredients.map(&:food).map(&:recipe_breakdown).flatten
  end
end
