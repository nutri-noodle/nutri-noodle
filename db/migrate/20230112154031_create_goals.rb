class CreateGoals < ActiveRecord::Migration[7.0]
  def change
    create_table :goals do |t|
      t.references :profile, null: false, foreign_key: true
      t.integer :nutrient_id_filter, array: true
      t.timestamps
    end
  end
end
