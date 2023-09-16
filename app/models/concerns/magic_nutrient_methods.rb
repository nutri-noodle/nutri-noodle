# This adds methods to Nutrient, and classes that belong_to nutrient (FoodNutrient)
# that work off a nutrient_id to check some aspect of the nutrient.  For instance
# calories? is a method that returns true for nutrient id = 191.  That method
# can work in _any_ class that has a nutrient_id attribute without having to load
# the ruby nutrient object
module MagicNutrientMethods
  extend ActiveSupport::Concern

  included do
  end

  [
    :calories,
    :fat,
    :protein,
    :carbohydrates,
    :sodium,
    :saturated_fat,
    :cholesterol,
    :fiber,
    :sugars,
    :added_sugars,
    :cholesterol,
    :omega_3,
    :vitamin_a,
    :vitamin_b1,
    :vitamin_b2,
    :vitamin_b3,
    :pantothenic_acid,
    :vitamin_b6,
    :folate,
    :vitamin_b12,
    :vitamin_c,
    :vitamin_d,
    :vitamin_e,
    :vitamin_k,
    :calcium,
    :copper,
    :iron,
    :magnesium,
    :manganese,
    :phosphorus,
    :potassium,
    :selenium,
    :sodium,
    :zinc,
    :water
  ].each do |nutrient|
    eval <<-EOS
      def #{nutrient}?
        self.nutrient_id == Nutrient::NutrientIds::#{nutrient.to_s.upcase}
      end
    EOS
  end

  def base_nutrient?
    self.class.base_nutrients.include?(self.nutrient)
  end

  def macs_minus_cals?
    nutrient.in?(self.class.macronutrients - [self.class.calories])
  end

  def carb_fat_protein?
    nutrient.in?(self.class.carb_fat_protein)
  end

  def macronutrients?
    nutrient.in?(Nutrient.macronutrients)
  end

  class_methods do
    [:calories, :fat, :protein, :carbohydrates, :sodium, :saturated_fat, :cholesterol, :fiber, :sugars, :added_sugars].each do |nutrient|
      eval <<-EOS
        def #{nutrient}
          Nutrient.cached_nutrients[Nutrient::NutrientIds::#{nutrient.to_s.upcase}]
        end
      EOS
    end

    def carb_fat_protein
      @@carb_fat_protein ||= [carbohydrates, fat, protein]
    end

    def carb_fat_protein_fiber
      @@carb_fat_protein_fiber ||= [carbohydrates, fat, protein, fiber]
    end

    def macronutrients
      @@macronutrients ||= [calories, carbohydrates, fat, saturated_fat, protein, fiber]
    end

    # all goal sets must contain at least these base nutrients. we do not allow them to be filtered out.
    def base_nutrients
      @@base_nutrients ||= [calories, carbohydrates, fat, protein, fiber]
    end
  end
end
