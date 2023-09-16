class CreateMealTimes < ActiveRecord::Migration[7.0]
  def change
    create_table :meal_times do |t|
      t.string :name
      t.integer :display_order

      t.timestamps
    end unless table_exists?(:meal_times)
  end
end
