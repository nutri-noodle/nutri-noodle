class FoodTag < ApplicationRecord
  include TagAssociation
  tag_association :owner => :food, :inverse_of => :food_tags, :touch => true, :counter_cache => false

  after_create :allergens_changed
  after_destroy :allergens_changed

  def allergens_changed
    food.allergens_changed if tag.allergen?
  end

end
