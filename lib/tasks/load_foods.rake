require 'csv'
namespace :load do
  desc "load fast_and_fresh foods"
  task :fast_and_fresh=> [:environment] do |t|
    Food.transaction do
      CSV.read('../code/data/foods.csv', headers: true).each do |row|
        Food.create!(row)
      end
      CSV.read('../code/data/food_tags.csv', headers: true).each do |row|
        rs=FoodTag.create(row)
        if(!rs)
          puts row
          exit
        end
      end
      CSV.read('../code/data/food_nutrients.csv', headers: true).each do |row|
        rs=FoodNutrient.create(row)
        if(!rs)
          puts row
          exit
        end
      end
      CSV.read('../code/data/food_available_meal_times.csv', headers: true).each do |row|
        FoodAvailableMealTime.create!(row)
      end
    end
  end
end
