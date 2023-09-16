class CreateNutrientGoals < ActiveRecord::Migration[7.0]
  def change
    create_table :nutrient_goals do |t|
      t.references :goal, null: false, foreign_key: true
      t.references :nutrient, null: false, foreign_key: true
      t.float :amount
      t.float :upper_limit
      t.float :pct_calories
      t.float :target_lower_bound
      t.float :target_upper_bound
      t.float :below_target_percent
      t.float :above_target_percent
      t.boolean :overridden
      t.string :goal_type
      t.string :scope
      t.integer :meal_time_id
      t.integer :goal_generation_rule_id

      t.timestamps
    end
  end
end
