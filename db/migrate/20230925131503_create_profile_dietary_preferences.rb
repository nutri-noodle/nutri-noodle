class CreateProfileDietaryPreferences < ActiveRecord::Migration[7.0]
  def change
    create_table :profile_dietary_preferences do |t|
      t.references :profile, null: false, foreign_key: true
      t.bigint :dietary_preference_id
      t.timestamps
    end
    add_foreign_key(:profile_dietary_preferences, :tags, column: :dietary_preference_id)
  end
end
