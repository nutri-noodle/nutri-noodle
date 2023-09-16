class CreateClassification < ActiveRecord::Migration[7.0]
  def change
    create_table :classifications do |t|
      t.references :food_import, null: false, foreign_key: true
      t.references :food, null: false, foreign_key: true
      t.references :food_group, null: false, foreign_key: true
      t.integer :status

      t.timestamps
    end
  end
end
