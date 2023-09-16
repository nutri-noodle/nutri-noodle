class CreateGoalFactors < ActiveRecord::Migration[7.0]
  def change
    create_table :goal_factors do |t|
      t.references :goal, null: false, foreign_key: true
      t.references :nutrient, null: true, foreign_key: true
      t.string :scope
      t.references :meal_time, null: true, foreign_key: true
      t.string :name
      t.float :value
      t.boolean :overridden

      t.timestamps
    end
  end
end
