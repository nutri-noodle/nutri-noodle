module NutrientGoalDelegation
  extend ActiveSupport::Concern

  included do
    delegate :calories_conversion_factor, :model_daily_nutrient, :to=>:nutrient
    delegate :nutrient_class, :calories?, :protein?, :fat?, :carbohydrates?, :fiber?, :saturated_fat?, :cholesterol?, :sodium?, :macronutrient?, :to => :nutrient
    delegate :mineral?, :vitamin?, :carb_fat_protein?, :macronutrients?, :macs_minus_cals?, :label_name, :sub_nutrient?, :non_percentage_based_goal_type?, :to => :nutrient

    delegate :rounded_amount, :to => :nutrient
    delegate :name, :prefix => true, :to => :nutrient
  end
end
