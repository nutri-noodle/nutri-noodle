class CreateNutrientGoalWeights < ActiveRecord::Migration[7.0]
  def change
    create_table :nutrient_goal_weights do |t|
      t.references :goal, null: false, foreign_key: true
      t.references :nutrient, null: false, foreign_key: true
      t.boolean :index
      t.integer :weight_scope
      t.float :below_weight_goal
      t.float :above_weight_goal
      t.float :normalized_below_weight_goal
      t.float :normalized_above_weight_goal

      t.timestamps
    end
  end
end
