class CreateTags < ActiveRecord::Migration[7.0]
  def change
    create_table :tags do |t|
      t.string :name
      t.references :parent_tag, foreign_key: { to_table: :tags }
      t.timestamps
    end
    create_table :food_tags do |t|
      t.references :food
      t.references :tag
      t.boolean    :direct
      t.timestamps
    end
  end
end
