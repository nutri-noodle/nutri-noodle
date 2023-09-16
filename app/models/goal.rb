class Goal < ApplicationRecord
  belongs_to :profile, :inverse_of =>:goal
  # joins to :nutrient here breaks tests in funny ways
  has_many :nutrient_goals, -> {includes(:nutrient).order(:nutrient_id)}, :autosave=>true, :dependent=>:destroy, :inverse_of => :goal
  has_many :nutrient_goal_weights, -> {includes(:nutrient).order(:nutrient_id)}, :autosave=>true, :dependent=>:destroy, :inverse_of => :goal
  has_many :goal_factors, :inverse_of=>:goal, :dependent=>:destroy, :autosave=>true
  has_one  :goal_weight
  def calorie_goal
    goal_for("Calories")
  end

  def rounded_calorie_goal
    calorie_goal.round
  end

  def calorie_goal_nutrient
    goal_nutrient_for('Calories')
  end

  def find_goal_nutrient(nutrient, meal = nil)
    if meal # a nil meal_time_id is a daily goal_nutrient but we want this to return nil if "meal" argument is given
      goal_nutrients.detect{|gsn| gsn.nutrient_id == nutrient.id && gsn.meal_time_id == meal.meal_time_id && gsn.meal?}
    else # this will return the daily goal if meal_time_id is nil, which is what we want
      goal_nutrients.detect{|gsn| gsn.nutrient_id == nutrient.id && gsn.meal_time_id.nil?}
    end
  end

  def goal_for(name)
    # grab a default?
    goal_nutrient_for(name)&.amount
  end

  def goal_nutrient_for(name)
    ActiveRecord::Associations::Preloader.new.preload(goal_nutrients, [:nutrient])
    goal_nutrients.detect do |goal_nutrient|
      goal_nutrient.nutrient_name == name && goal_nutrient.meal_time_id.nil? && goal_nutrient.nutrient.enabled == true && !goal_nutrient.marked_for_destruction?
    end
  end

  def rounded_calorie_goal_for(meal_time_id)
    rounded_calorie_goal * eating_pattern.pattern_for(meal_time_id)
  end

  def nutrient_id_filter=(val)
    @nutrient_filter = nil
    super
  end

  def nutrient_filter
    @nutrient_filter ||= (Nutrient.where(:id=>nutrient_id_filter) - Nutrient.base_nutrients)
  end

  # the form has a list of included nutrients, the filter has a list of excluded nutrients, this converts between
  # the two forms
  def self.as_nutrient_id_filter(goal_nutrient_id_filter)
    (Nutrient.model_nutrients-Nutrient.base_nutrients).map(&:id).map(&:to_s) - goal_nutrient_id_filter
  end

  delegate :as_nutrient_id_filter, :to => :class
end

