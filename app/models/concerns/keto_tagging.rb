module KetoTagging
  extend ActiveSupport::Concern
# Definition:
# A “keto” recipe/meal has
# * a minimum of 70% fat,
# * a maximum of 10% carbs
# * between 10-20% protein.
#
# Notes:
#  This module implements both a rails and a SQL version of the keto tagging
#  algorithm.
  included do
    after_save :update_keto_tag
  end
  def is_keto_friendly?
    fat * Nutrient.fat.calories_conversion_factor >= calories * 0.6 &&
    carbohydrates * Nutrient.carbohydrates.calories_conversion_factor <= calories * 0.15 &&
    (calories * 0.10 .. calories * 0.40).include?(protein * Nutrient.protein.calories_conversion_factor)
  end

  def update_keto_tag
    if(is_keto_friendly?)
      food_tags.find_or_create_by(tag: Tag.keto_tag)
    else
      food_tags.where(tag: Tag.keto_tag).delete_all
    end
  end
  KETO_SQL_CLAUSE=%Q{
      SELECT distinct foods.id as food_id from foods
      JOIN food_nutrients cal on cal.food_id = foods.id and cal.nutrient_id = #{Nutrient::NutrientIds::CALORIES}
      JOIN food_nutrients fat on fat.food_id = foods.id and fat.nutrient_id = #{Nutrient::NutrientIds::FAT}
      JOIN food_nutrients carb on carb.food_id = foods.id and carb.nutrient_id = #{Nutrient::NutrientIds::CARBOHYDRATES}
      JOIN food_nutrients protein on protein.food_id = foods.id and protein.nutrient_id = #{Nutrient::NutrientIds::PROTEIN}
      WHERE
      fat.amount * #{Nutrient.fat.calories_conversion_factor} >= cal.amount * 0.6
      and
      carb.amount * #{Nutrient.carbohydrates.calories_conversion_factor} <= cal.amount * 0.1
      and
      protein.amount * #{Nutrient.protein.calories_conversion_factor} between cal.amount * 0.1 and cal.amount * 0.4
  }
  class_methods do
    def update_keto_tags
      add_new_keto_tags
      remove_stale_keto_tags
    end
    def add_new_keto_tags
      # add new tags
      connection.execute %Q{
        WITH keto_foods as (#{KETO_SQL_CLAUSE})
        insert into food_tags(food_id, tag_id, created_at, updated_at)
          select keto_foods.food_id, #{Tag.keto_tag.id}, now(), now() from keto_foods
          where keto_foods.food_id not in (select food_id from food_tags where tag_id = #{Tag.keto_tag.id})
      }
    end
    def remove_stale_keto_tags
      # remove old tags
       connection.execute %Q{
        WITH keto_foods as (#{KETO_SQL_CLAUSE})
        delete from food_tags
        where tag_id = #{Tag.keto_tag.id} and food_id not in (select food_id from keto_foods)
      }
    end
  end
end
