class CreateFoodProfileScores < ActiveRecord::Migration[7.0]
  def change
    create_table :food_profile_scores do |t|
      t.references :food, null: false, foreign_key: true
      t.references :profile, null: false, foreign_key: true
      t.float :score

      t.timestamps
    end
  end
end
