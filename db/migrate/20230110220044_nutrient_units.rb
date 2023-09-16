class NutrientUnits < ActiveRecord::Migration[7.0]
  def change
    create_table :nutrient_units do |t|
      t.belongs_to :nutrient, null: false, index: false
      t.string :name
      t.string :abbreviation_name
      t.float :multiplier
      t.integer :round_to
      t.boolean :default
      t.timestamps
    end
  end
end
