class Ingredient < ApplicationRecord
  include ServingRules

  belongs_to :recipe, :class_name=>"Food", :inverse_of => :ingredients, :touch => true
  belongs_to :food,   :class_name=>"Food", :inverse_of => :used_as_ingredients
  belongs_to :retention_factor
  has_one :participant, :through=>:recipe
  has_one :organization, :through=>:recipe

  has_many :retention_factor_nutrients, :through => :retention_factor
  belongs_to :measurement
  validates_numericality_of :serving_amount
  validates_numericality_of :display_order, :greater_than => 0, :only_integer => true, :allow_nil => true,
    :if => Proc.new { |ingredient| ingredient.recipe && ingredient.recipe.recipe? }
  attr_accessor :meal
  has_many :tags, :through => :food
  delegate :name, :to => :food

  before_save :rationalize_measurement
  after_save :maintain_ingredient_history, :if=> Proc.new { |ingredient| ingredient.recipe && ingredient.recipe.recipe? }

  def copy_if_needed(other_participant, is_offered = true, attributes = {}, to_copy = nil)
    unless food.available_as_ingredient_to?(other_participant)
      copy_of_food = food.copy_to(other_participant, is_offered, attributes, to_copy)

      ingredient_measurement = copy_of_food.measurements.detect do |measurement| measurement.name == self.measurement.name end
      # if we didn't find by name, because we now change measurements, we'll go with multipler
      ingredient_measurement ||= copy_of_food.measurements.detect do |measurement|
        (measurement.multiplier - self.measurement.multiplier).abs <= 0.001
      end

      update!(:food_id => copy_of_food.id, :measurement_id => ingredient_measurement.id)
    end
  end

  def nutrients
    retention_hash = Hash[*retention_factor_nutrients.collect {|n| [n.nutrient_id, n.multiplier]}.flatten]
    # MHL - apply the retention factor
    food.enabled_food_nutrients.present? ?
      Hash[*food.enabled_food_nutrients.collect {|n|[n.nutrient_id,n.amount * multiplier * (retention_hash[n.nutrient_id] || 1.0) ]}.flatten] : {}
  end

  def grams
    (serving_amount * (food.grams || 0) * measurement_multiplier).round
  end

  def maintain_ingredient_history
    object = participant || organization
    ingredient_history = object.ingredient_histories.where(:food_id => self.food_id).first_or_initialize
    ingredient_history.update(:measurement => measurement, :serving_amount => serving_amount, :updated_at => Time.now)
    true
  end

  def prep_scale_factor
    recipe.recipe_yield / 4.0
  end

  def estimate_times
    case
    when food.recipe?
      food.estimate_times
    when food_name =~ /cut into|sliced|diced|chopped|cubed|minced|peeled|grated|shredded|cut in chunks/
      {active_time: prep_scale_factor, cooking_time: 0, max_time: 0}
    when food_name =~ /roasted/
      {active_time: 0, cooking_time: 30, max_time: 0}
    else
      {active_time: 0, cooking_time: 0, max_time: 0}
    end
  end

  def self.from_json(attributes)
    self.new(attributes.except("id","measurement", "food")).tap do |obj|
      obj.food = Food.from_json(attributes["food"])
      obj.association(:food).loaded!
      obj.measurement = Measurement.new(attributes["measurement"])
      obj.measurement.food = obj.food
      obj.association(:measurement).loaded!
      obj.id = attributes["id"]
      obj.clear_changes_information
    end
  end
end
