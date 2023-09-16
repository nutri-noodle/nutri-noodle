class CreateProfiles < ActiveRecord::Migration[7.0]
  def change
    create_table :profiles do |t|
      t.string :name
      t.integer :min_age
      t.integer :max_age
      t.string :gender
      t.timestamps
    end
  end
end
