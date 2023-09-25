class CreateProfileAllergens < ActiveRecord::Migration[7.0]
  def change
    create_table :profile_allergens do |t|
      t.references :profile, null: false, foreign_key: true
      t.bigint :allergen_id
      t.timestamps
    end
    add_foreign_key(:profile_allergens, :tags, column: :allergen_id)
  end
end
