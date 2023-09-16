class CreateFoods < ActiveRecord::Migration[7.0]
  def change
    create_table :foods do |t|
      t.string :type
      t.string :name
      t.string :external_food_id
      t.float :grams
      t.string :serving_unit
      t.string :brand
      t.text :comment
      t.string :tag
      t.string :category
      t.integer :source_id
      t.text :short_desc
      t.boolean :enabled
      t.string :common_name
      t.string :display_name
      t.string :descriptors
      t.tsvector :vector
      t.integer :template_id
      t.text :reference_url
      t.string :from
      t.text :notes
      t.string :department
      t.string :major_category
      t.string :subcategory
      t.tsvector :ingredients_vector
      t.integer :total_time
      t.integer :active_time
      t.integer :estimated_active_time
      t.integer :estimated_total_time
      t.timestamps
    end

    create_table :food_nutrients do |t|
      t.references :nutrient
      t.references :food
      t.float :amount
      t.boolean :overridden
      t.timestamps
    end

    create_table :measurement_source do |t|
      t.string :name
      t.timestamps
    end

    create_table :measurements do |t|
      t.references :food
      t.integer :measurement_source_id
      t.string :name
      t.float :multiplier
      t.boolean :default
      t.boolean :enabled
      t.float :default_amount
      t.float :minimum_amount
      t.float :increment_amount
      t.timestamps
    end

    create_table :ingredients do |t|
      t.references :recipe, foreign_key: { to_table: :foods }
      t.references :food
      t.float :serving_amount
      t.references :measurement
      t.integer :display_order
      t.string :alternate_name
      t.text :notes
      t.timestamps
    end

    create_table :recipe_steps do |t|
      t.references :recipe, foreign_key: { to_table: :foods }
      t.text :instruction
      t.integer :display_order
      t.timestamps
    end

    create_table :food_available_meal_times do |t|
      t.references :meal_time, null: false, foreign_key: true
      t.references :food, null: false, foreign_key: true

      t.timestamps
    end
  end
end
