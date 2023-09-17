# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2023_09_16_140205) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "classification_rules", force: :cascade do |t|
    t.string "rule"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "classifications", force: :cascade do |t|
    t.bigint "food_import_id", null: false
    t.bigint "food_id", null: false
    t.bigint "food_group_id", null: false
    t.integer "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["food_group_id"], name: "index_classifications_on_food_group_id"
    t.index ["food_id"], name: "index_classifications_on_food_id"
    t.index ["food_import_id"], name: "index_classifications_on_food_import_id"
  end

  create_table "food_available_meal_times", force: :cascade do |t|
    t.bigint "meal_time_id", null: false
    t.bigint "food_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["food_id"], name: "index_food_available_meal_times_on_food_id"
    t.index ["meal_time_id"], name: "index_food_available_meal_times_on_meal_time_id"
  end

  create_table "food_groups", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "food_imports", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "food_nutrients", force: :cascade do |t|
    t.bigint "nutrient_id"
    t.bigint "food_id"
    t.float "amount"
    t.boolean "overridden"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["food_id"], name: "index_food_nutrients_on_food_id"
    t.index ["nutrient_id"], name: "index_food_nutrients_on_nutrient_id"
  end

  create_table "food_profile_scores", force: :cascade do |t|
    t.bigint "food_id", null: false
    t.bigint "profile_id", null: false
    t.float "score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["food_id"], name: "index_food_profile_scores_on_food_id"
    t.index ["profile_id"], name: "index_food_profile_scores_on_profile_id"
  end

  create_table "food_tags", force: :cascade do |t|
    t.bigint "food_id"
    t.bigint "tag_id"
    t.boolean "direct"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["food_id"], name: "index_food_tags_on_food_id"
    t.index ["tag_id"], name: "index_food_tags_on_tag_id"
  end

  create_table "foods", force: :cascade do |t|
    t.string "type"
    t.string "name"
    t.string "external_food_id"
    t.float "grams"
    t.string "serving_unit"
    t.string "brand"
    t.text "comment"
    t.string "tag"
    t.string "category"
    t.integer "source_id"
    t.text "short_desc"
    t.boolean "enabled"
    t.string "common_name"
    t.string "display_name"
    t.string "descriptors"
    t.tsvector "vector"
    t.integer "template_id"
    t.text "reference_url"
    t.string "from"
    t.text "notes"
    t.string "department"
    t.string "major_category"
    t.string "subcategory"
    t.tsvector "ingredients_vector"
    t.integer "total_time"
    t.integer "active_time"
    t.integer "estimated_active_time"
    t.integer "estimated_total_time"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "goal_factors", force: :cascade do |t|
    t.bigint "goal_id", null: false
    t.bigint "nutrient_id"
    t.string "scope"
    t.bigint "meal_time_id"
    t.string "name"
    t.float "value"
    t.boolean "overridden"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["goal_id"], name: "index_goal_factors_on_goal_id"
    t.index ["meal_time_id"], name: "index_goal_factors_on_meal_time_id"
    t.index ["nutrient_id"], name: "index_goal_factors_on_nutrient_id"
  end

  create_table "goals", force: :cascade do |t|
    t.bigint "profile_id", null: false
    t.integer "nutrient_id_filter", array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["profile_id"], name: "index_goals_on_profile_id"
  end

  create_table "ingredients", force: :cascade do |t|
    t.bigint "recipe_id"
    t.bigint "food_id"
    t.float "serving_amount"
    t.bigint "measurement_id"
    t.integer "display_order"
    t.string "alternate_name"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["food_id"], name: "index_ingredients_on_food_id"
    t.index ["measurement_id"], name: "index_ingredients_on_measurement_id"
    t.index ["recipe_id"], name: "index_ingredients_on_recipe_id"
  end

  create_table "meal_times", force: :cascade do |t|
    t.string "name"
    t.integer "display_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "measurement_source", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "measurements", force: :cascade do |t|
    t.bigint "food_id"
    t.integer "measurement_source_id"
    t.string "name"
    t.float "multiplier"
    t.boolean "default"
    t.boolean "enabled"
    t.float "default_amount"
    t.float "minimum_amount"
    t.float "increment_amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["food_id"], name: "index_measurements_on_food_id"
  end

  create_table "medical_conditions", force: :cascade do |t|
    t.string "name"
    t.integer "display_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "role"
    t.string "content"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "nutrient_goal_weights", force: :cascade do |t|
    t.bigint "goal_id", null: false
    t.bigint "nutrient_id", null: false
    t.boolean "index"
    t.integer "weight_scope"
    t.float "below_weight_goal"
    t.float "above_weight_goal"
    t.float "normalized_below_weight_goal"
    t.float "normalized_above_weight_goal"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["goal_id"], name: "index_nutrient_goal_weights_on_goal_id"
    t.index ["nutrient_id"], name: "index_nutrient_goal_weights_on_nutrient_id"
  end

  create_table "nutrient_goals", force: :cascade do |t|
    t.bigint "goal_id", null: false
    t.bigint "nutrient_id", null: false
    t.float "amount"
    t.float "upper_limit"
    t.float "pct_calories"
    t.float "target_lower_bound"
    t.float "target_upper_bound"
    t.float "below_target_percent"
    t.float "above_target_percent"
    t.boolean "overridden"
    t.string "goal_type"
    t.string "scope"
    t.integer "meal_time_id"
    t.integer "goal_generation_rule_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["goal_id"], name: "index_nutrient_goals_on_goal_id"
    t.index ["nutrient_id"], name: "index_nutrient_goals_on_nutrient_id"
  end

  create_table "nutrient_units", force: :cascade do |t|
    t.bigint "nutrient_id", null: false
    t.string "name"
    t.string "abbreviation_name"
    t.float "multiplier"
    t.integer "round_to"
    t.boolean "default"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "nutrients", force: :cascade do |t|
    t.string "nutrient_class"
    t.string "name"
    t.boolean "enabled"
    t.string "units"
    t.boolean "daily_nutrient"
    t.string "nutr_no"
    t.integer "display_order"
    t.float "rdi_amount"
    t.float "calories_conversion_factor"
    t.string "default_goal_type"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "profile_medical_conditions", force: :cascade do |t|
    t.bigint "profile_id", null: false
    t.bigint "medical_condition_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["medical_condition_id"], name: "index_profile_medical_conditions_on_medical_condition_id"
    t.index ["profile_id"], name: "index_profile_medical_conditions_on_profile_id"
  end

  create_table "profiles", force: :cascade do |t|
    t.string "name"
    t.integer "min_age"
    t.integer "max_age"
    t.string "gender"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "recipe_steps", force: :cascade do |t|
    t.bigint "recipe_id"
    t.text "instruction"
    t.integer "display_order"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recipe_id"], name: "index_recipe_steps_on_recipe_id"
  end

  create_table "tags", force: :cascade do |t|
    t.string "name"
    t.bigint "parent_tag_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_tag_id"], name: "index_tags_on_parent_tag_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "classifications", "food_groups"
  add_foreign_key "classifications", "food_imports"
  add_foreign_key "classifications", "foods"
  add_foreign_key "food_available_meal_times", "foods"
  add_foreign_key "food_available_meal_times", "meal_times"
  add_foreign_key "food_profile_scores", "foods"
  add_foreign_key "food_profile_scores", "profiles"
  add_foreign_key "goal_factors", "goals"
  add_foreign_key "goal_factors", "meal_times"
  add_foreign_key "goal_factors", "nutrients"
  add_foreign_key "goals", "profiles"
  add_foreign_key "ingredients", "foods", column: "recipe_id"
  add_foreign_key "messages", "users"
  add_foreign_key "nutrient_goal_weights", "goals"
  add_foreign_key "nutrient_goal_weights", "nutrients"
  add_foreign_key "nutrient_goals", "goals"
  add_foreign_key "nutrient_goals", "nutrients"
  add_foreign_key "profile_medical_conditions", "medical_conditions"
  add_foreign_key "profile_medical_conditions", "profiles"
  add_foreign_key "recipe_steps", "foods", column: "recipe_id"
  add_foreign_key "tags", "tags", column: "parent_tag_id"
end
