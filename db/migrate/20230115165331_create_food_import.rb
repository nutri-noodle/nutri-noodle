class CreateFoodImport < ActiveRecord::Migration[7.0]
  def change
    create_table :food_imports do |t|
      t.string :name

      t.timestamps
    end
  end
end
