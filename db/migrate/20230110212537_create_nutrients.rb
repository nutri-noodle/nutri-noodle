class CreateNutrients < ActiveRecord::Migration[7.0]
  def change
    create_table :nutrients do |t|
      t.string :nutrient_class
      t.string :name
      t.boolean :enabled
      t.string :units
      t.boolean :daily_nutrient
      t.string :nutr_no
      t.integer :display_order
      t.float :rdi_amount
      t.float :calories_conversion_factor
      t.string :default_goal_type
      t.timestamps
    end
  end
end
