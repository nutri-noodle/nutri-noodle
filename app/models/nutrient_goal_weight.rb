class NutrientGoalWeight < ApplicationRecord
  belongs_to :goal, :inverse_of=>:nutrient_goal_weights

  belongs_to :nutrient

  # Delegation to nutrient methods
  include NutrientGoalDelegation

  MULTI_DAY_SCOPE = 1
  DAILY_SCOPE = 2
  MEAL_SCOPE = 3

  ALL_SCOPES =[DAILY_SCOPE, MULTI_DAY_SCOPE, MEAL_SCOPE]

  def self.scope_converter(goal_nutrient_scope)
    case goal_nutrient_scope
    when 'weekly' then MULTI_DAY_SCOPE
    when 'daily' then DAILY_SCOPE
    else MEAL_SCOPE
    end
  end

  def scope_name
    self.class.scope_name(self.weight_scope)
  end

  def self.scope_name(weight_scope)
    case weight_scope
    when MEAL_SCOPE
      'meal'
    when DAILY_SCOPE
      'daily'
    when MULTI_DAY_SCOPE
      'multi_day'
    else
      nil
    end
  end

  def meal?
    weight_scope == MEAL_SCOPE
  end

  def index_scope?(scope)
    weight_scope == scope && index_weight?
  end

  def model_scope?(scope)
    weight_scope == scope && model_weight?
  end

  def daily?
    weight_scope == DAILY_SCOPE
  end

  def index_daily?
    index_scope?(DAILY_SCOPE)
  end

  def model_daily?
    index_scope?(DAILY_SCOPE)
  end

  def multi_day?
    weight_scope == MULTI_DAY_SCOPE
  end

  def index_multi_day?
    index_scope?(MULTI_DAY_SCOPE)
  end

  def model_multi_day?
    model_scope?(MULTI_DAY_SCOPE)
  end

  def model_weight?
    index == false
  end

  def index_weight?
    !model_weight?
  end

  scope :weight_scope, lambda {|weight_scope| where(:weight_scope=>weight_scope)}
  scope :model_weights, -> {where(:index=>false)}

  def normalize_weights
    goal_weight.touch
  end

  validates_presence_of :nutrient_id
  validates :weight_scope, :inclusion => [MULTI_DAY_SCOPE, DAILY_SCOPE, MEAL_SCOPE]
end
