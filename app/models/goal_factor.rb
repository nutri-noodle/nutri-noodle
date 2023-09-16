class GoalFactor < ApplicationRecord
  belongs_to :goal, :inverse_of => :goal_factors, :touch => true
  belongs_to :nutrient
  belongs_to :meal_time

  validates_presence_of :goal
  delegate :participant, :to=>:goal

  scope :ranked_order, lambda {
    joins(:goal_generation_rule).eager_load(:nutrient).order(Arel.sql("goal_generation_rules.rank asc, nutrients.display_order asc, goal_factors.name asc"))
  }

  scope :nutrient_order, lambda {
    joins(:goal_generation_rule).eager_load(:nutrient).order(Arel.sql("nutrients.display_order asc, goal_generation_rules.rank asc, goal_factors.name asc"))
  }

  KEY_ATTRIBUTES = %W{name nutrient_id scope meal_time_id}
  def key_attributes
    slice(*KEY_ATTRIBUTES)
  end

  def matching_factor(factors)
    @matching_factor ||= possible_matches(factors).detect{ |gsf| matches?(gsf) }
  end

  def possible_matches(factors)
    @possible_matches ||= factors
  end

  def check_for_changes(factors)
    check_value_changed(factors)
    check_overridden(factors)
  end

  def value_has_changed?(match)
    match.value.to_f.round(1) != value.to_f.round(1)
  end

  def check_value_changed(factors)
    match = matching_factor(factors)
    if old_value = match&.value
      self.value = old_value unless value_has_changed?(match)
    end
  end

  def matches?(other)
    return false if other == self
    key_attributes == other.key_attributes
  end
end
