require 'csv'

CSV.read('db/data/nutrients.csv', headers: true).each do |row|
  Nutrient.create!(row)
end unless Nutrient.exists?

CSV.read('db/data/nutrient_units.csv', headers: true).each do |row|
  NutrientUnit.create!(row)
end unless NutrientUnit.exists?


unless Tag.exists?
  Tag.transaction do
    CSV.read('db/data/medical_conditions.csv', headers: true).each do |row|
      MedicalCondition.create!(row)
    end

    CSV.read('db/data/allergens.csv', headers: true).each do |row|
      Tag.create!(row)
    end unless Tag.exists?

    CSV.read('db/data/main_ingredients.csv', headers: true).each do |row|
      Tag.create!(row)
    end

    CSV.read('db/data/speed_tags.csv', headers: true).each do |row|
      Tag.create!(row)
    end

    CSV.read('db/data/dietary_preferences.csv', headers: true).each do |row|
      Tag.create!(row)
    end
  end
end

CSV.read('db/data/meal_times.csv', headers: true).each do |row|
  MealTime.create!(row)
end unless MealTime.exists?

Profile.create!(name: "default", min_age: 0, max_age: 999) unless Profile.exists?

if((default=Profile.find_by_name("default")) && !default.goal.present?)
  Profile.transaction do
    goal = default.create_goal!
    CSV.read('db/data/nutrient_goals.csv', headers: true).each do |row|
      NutrientGoal.create!(row.to_h.merge(goal: goal))
    end
    CSV.read('db/data/nutrient_goal_weights.csv', headers: true).each do |row|
      NutrientGoalWeight.create!(row.to_h.merge(goal: goal))
    end
  end
end

CSV.read('db/data/food_groups.csv', headers: true, col_sep: "\t").each do |row|
  FoodGroup.create!(row)
end unless FoodGroup.exists?
