class FoodAvailableMealTime < ApplicationRecord

  belongs_to :food, :inverse_of => :available_meal_times
  belongs_to :meal_time
  delegate :name, :to => :meal_time
end
