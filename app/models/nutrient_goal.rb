class NutrientGoal < ApplicationRecord
  belongs_to :goal, :inverse_of => :nutrient_goals, :touch => true
  belongs_to :nutrient
  belongs_to :meal_time, optional: true
  delegate :name, :to => :meal_time, :prefix => true, :allow_nil => true
  attr_accessor :copying

  validates_presence_of :goal
  validates_presence_of :nutrient

  validate :calorie_range, :if => :calories?
  validate :target_range, :if => :range_but_not_calories?

  # Delegation to nutrient methods
  include NutrientGoalDelegation
  def pretty_amount(amount)
    nutrient.pretty_amount(amount, 1)
  end

  def pretty_amount_clean(amount)
    nutrient.pretty_amount_clean(amount, 1)
  end

  class NutrientGoalValidator < ActiveModel::Validator
    attr_reader :fields

    def validate_presence(record, type, fields)
      return unless record.goal_type == type
      return if record.marked_for_destruction?
      fields.each do |attr|
        if record.send(attr).blank?
          attr_as_s = attr.to_s.gsub('target_', '').humanize
          period = 'Daily'
          if record.meal?
            period = record.meal_time_name
          end

          record.errors.add(attr, "#{period} #{attr_as_s} can't be blank")
        end
      end
    end
  end

  class RangeValidator < NutrientGoalValidator
    def validate(record)
      validate_presence(record, 'range', [:target_lower_bound, :target_upper_bound])
    end
  end
  validates_with RangeValidator

  class CaloriesValidator < NutrientGoalValidator
    def validate(record)
      validate_presence(record, 'calories', [:amount])
    end
  end
  validates_with CaloriesValidator

  class MaximumValidator < NutrientGoalValidator
    def validate(record)
      validate_presence(record, 'maximum', [:amount])
    end
  end
  validates_with MaximumValidator

  class MinimumValidator < NutrientGoalValidator
    def validate(record)
      validate_presence(record, 'minimum', [:amount])
    end
  end
  validates_with MinimumValidator

  class MinimumWithUpperLimitValidator < NutrientGoalValidator
    def validate(record)
      validate_presence(record, 'minimum_with_upper_limit', [:amount, :upper_limit])
    end
  end
  validates_with MinimumWithUpperLimitValidator


  class MaximumWithInvisibleLowerLimitValidator < NutrientGoalValidator
    def validate(record)
      validate_presence(record, 'maximum_with_invisible_lower_limit', [:amount, :upper_limit])
    end
  end
  validates_with MaximumWithInvisibleLowerLimitValidator

  class DynamicMaximumValidator < NutrientGoalValidator
    def validate(record)
      validate_presence(record, 'dynamic_maximum', [:pct_calories])
    end
  end
  validates_with DynamicMaximumValidator


  class DynamicMinimumValidator < NutrientGoalValidator
    def validate(record)
      validate_presence(record, 'dynamic_minimum', [:pct_calories])
    end
  end
  validates_with DynamicMinimumValidator


  class CalculatedMaximumValidator < NutrientGoalValidator
    def validate(record)
      validate_presence(record, 'calculated_maximum', [:pct_calories])
    end
  end
  validates_with CalculatedMaximumValidator

  class CalculatedMinimumValidator < NutrientGoalValidator
    def validate(record)
      validate_presence(record, 'calculated_minimum', [:pct_calories])
    end
  end
  validates_with CalculatedMinimumValidator

  scope :scope_order, -> { order(Arel.sql("case scope when 'multi' then 0 when 'daily' then 1 else 2 end ")) }
  scope :daily, lambda { where(:scope => 'daily')}
  scope :meal, lambda { where(:scope => 'meal')}
  scope :for_nutrient, lambda {|n| where(:nutrient_id => n.id)}
  scope :for_meal_time, lambda {|mt| mt.nil?? where(:meal_time_id => nil) : meal.where(:meal_time_id => mt.id)}

  KEY_ATTRIBUTES = %W{nutrient_id scope meal_time_id}
  def key_attributes
    attributes.slice(*KEY_ATTRIBUTES)
  end

  def default_goal_type
    self.goal_type = nutrient.default_goal_type if goal_type.blank?
    self
  end

  def self.matching_goal_nutrient(daily, meals, hash = {})
    if hash[:scope] == "daily"
      daily
    elsif meals.any?
      meals.detect{|gsn| gsn.meal_time_id.to_s == hash[:meal_time_id]}
    else
      false
    end
  end

  def calculated_fields_in_user_units
    GOAL_ATTRIBUTES_IN_USER_UNITS.map{|field| [field.to_s, "#{field.to_s}_in_user_units"]}.flatten
  end

  def changeable_values(hash)
    hash.keys.select{|attrs| attrs.in?(calculated_fields_in_user_units)}
  end

  def goal_type_overridden?(hash)
    hash.has_key?("goal_type") && hash["goal_type"] != self.goal_type || will_save_change_to_goal_type?
  end

  def values_overridden?(hash)
    changeable_values = changeable_values(hash)
    true_count = changeable_values.sum do |value|
      hash[value].to_f == self.send(value).to_f ? 1 : 0
    end
    true_count != changeable_values.size
  end

  def check_overridden(overridden_status, hash)
    if overridden_status
      hash[:overridden] = goal_type_overridden?(hash) || values_overridden?(hash)
    end
  end

  def create_shell_daily_calorie_goal(amount)
    NutrientGoal.new(:goal_type => self.goal_type, :amount => amount, :nutrient_id => self.nutrient_id)
  end

  DYNAMIC_RANGE = :dynamic_range
  DYNAMIC_MAXIMUM = :dynamic_maximum
  DYNAMIC_MINIMUM = :dynamic_minimum
  CALORIES = :calories
  MINIMUM_WITH_UPPER_LIMIT = :minimum_with_upper_limit
  MAXIMUM_WITH_INVISIBLE_LOWER_LIMIT = :maximum_with_invisible_lower_limit
  MAXIMUM = :maximum
  MINIMUM = :minimum
  CALCULATED_RANGE = :calculated_range
  CALCULATED_MINIMUM = :calculated_minimum
  CALCULATED_MAXIMUM = :calculated_maximum
  RANGE = :range


  GOAL_TYPES = [
     CALCULATED_MAXIMUM,
     CALCULATED_MINIMUM,
     CALCULATED_RANGE,
     DYNAMIC_RANGE,
     DYNAMIC_MAXIMUM,
     DYNAMIC_MINIMUM,
     CALORIES,
     MINIMUM_WITH_UPPER_LIMIT,
     MAXIMUM_WITH_INVISIBLE_LOWER_LIMIT,
     MAXIMUM,
     MINIMUM,
     CALCULATED_RANGE,
     CALCULATED_MAXIMUM,
     CALCULATED_MINIMUM,
     RANGE
  ]

  CALORIE_DEPENDENT_GOAL_TYPES=[
    CALORIES,
    CALCULATED_MAXIMUM,
    CALCULATED_MINIMUM,
    CALCULATED_RANGE,
    DYNAMIC_RANGE,
    DYNAMIC_MAXIMUM,
    DYNAMIC_MINIMUM,
    RANGE
  ]


  def assign_attributes(new_attributes)
    return unless new_attributes.respond_to?(:keys) # Hash or ActionController::Parameters

    attributes = new_attributes.stringify_keys
    [:nutrient_id, :nutrient, :goal_type].each do |value_dependent_attribute|
      self.send("#{value_dependent_attribute}=", attributes[value_dependent_attribute.to_s]) unless attributes[value_dependent_attribute.to_s].nil?
    end

    super
  end

  GOAL_ATTRIBUTES_IN_USER_UNITS = [:amount, :target_lower_bound, :target_upper_bound, :pct_calories, :below_target_percent, :above_target_percent, :upper_limit]
  # If you change the conditional logic in here to depend on a new attribute, you must change assign_attributes so that mass
  # assignment works.
  GOAL_ATTRIBUTES_IN_USER_UNITS.each do |method|
    eval <<-EOS

    # here resides some ugly code about setting units.
    def #{method}_in_user_units
      case
      when fiber?
        ((#{method} || 0.0) * 1000).to_i # fiber is in grams per 1000 calories. Go figure.
      when percent_units?, range?, saturated_fat?
        pct = #{method}
        if pct.nil? && nutrient.respond_to?("default_#{method}")
          pct ||= nutrient.send("default_#{method}")
        end

        (pct * 100.0).round
      else
        rounded_amount(#{method})
      end
    end
    def #{method}_in_user_units=(val)
      case
      when fiber?
        self.#{method}=val.fraction_to_float / 1000.0 # fiber is in grams per 1000 calories. Go figure.
      when percent_units?
        self.#{method}=val.fraction_to_float / 100.0
      when range?
        self.#{method}=val.fraction_to_float / 100.0
      when saturated_fat?
        self.#{method}=val.fraction_to_float / 100.0
      else
        self.#{method}=nutrient.to_base_amount(val.fraction_to_float)
      end
    end
    def #{method}_goal_amount_in_user_units(actual_calories, target_calories)
      case
      when dynamic?
        #{method}_in_user_units * actual_calories
      when calculated?
        #{method}_in_user_units * target_calories
      else
        #{method}_in_user_units
      end
    end
  EOS
  end

  def method_missing(method, *args, &block)
    if (NutrientGoal::GOAL_TYPES.map {|t| "#{t}?"}.include?(method.to_s))
      return self.goal_type == method.to_s[0...-1]
    else
      super
    end
  end

  def respond_to?(method, include_all = false)
    if (NutrientGoal::GOAL_TYPES.map {|t| "#{t}?"}.include?(method.to_s))
      true
    else
      super
    end
  end

  def daily?
    scope == 'daily'
  end

  def meal?
    scope == 'meal'
  end
  alias :meal_scope? :meal?

  def classify
    goal_type.nil? ? nil : goal_type.to_sym
  end
  alias_method :classification, :classify

  def depends_on_calories?
    !(goal_type =~ /calculated|dynamic/).nil?
  end
  alias_method :percent_units?, :depends_on_calories?

  def dynamic?
    !(goal_type =~ /dynamic/).nil?
  end

  def range?
    !(goal_type =~ /range/).nil?
  end

  def calculated?
    !(goal_type =~ /calculated/).nil?
  end

  def range?
    !(goal_type =~ /range/).nil?
  end

  def can_be_affected_by_exercise?
    # must match JS if changed
    if nutrient.name.downcase == "saturated fat" || nutrient.name.downcase == 'calories'
      return true
    end
    return false
  end

  def goals_to_be_duplicated(conduit_goal_type = nil)
    meal_nutrients = self.goal.goal_nutrients.select{|gsn| gsn.nutrient_id == self.nutrient_id && gsn.meal? && gsn.id != self.id}
    test_goal_type = conduit_goal_type.presence || self.goal_type
    if test_goal_type.in?(Nutrient::NON_PERCENTAGE_BASED_GOAL_TYPES)
      return meal_nutrients.reject{|gsn| gsn.meal_time_id == 4}
    else
      return meal_nutrients
    end
  end

  def duplicate_meal_goals(conduit_goal_type = nil)
    goals_to_be_duplicated(conduit_goal_type).each{|gsn| gsn.build(self.attributes.except("id", "meal_time_id"))}
  end

  def duplicate_meals_text(conduit_goal_type = nil)
    test_goal_type = conduit_goal_type.presence || self.goal_type
    if test_goal_type.in?(Nutrient::NON_PERCENTAGE_BASED_GOAL_TYPES)
      "Same goals for breakfast, lunch, and dinner"
    else
      "Same goals for each meal"
    end
  end

  def replicated_meals?(conduit_goal_type = nil)
    goals_to_be_duplicated(conduit_goal_type).detect{|gsn| gsn.attributes.except("id", "meal_time_id") != self.attributes.except("id", "meal_time_id")}.nil?
  end

  def checked_value(params_replicated, replicated)
    replicated_value = params_replicated == "true" ? true : false
    return replicated_value unless params_replicated.nil?
    replicated
  end

  def build_attributes_for_replication_in_form(meal_duplicates, breakfast_attributes)
    if meal_duplicates
      keys_to_build = self.changeable_values(breakfast_attributes)
      breakfast_attributes.slice(*keys_to_build)
    else
      {}
    end
  end

  def replicate_meal_goal_in_form(index, form_hash, meal_duplicates, breakfast_values)
    return unless (index.in?(self.meals_to_be_replicated) && meal_duplicates)
    attributes_to_build = self.build_attributes_for_replication_in_form(meal_duplicates, breakfast_values)
    form_hash.merge!(attributes_to_build)
  end

  # case on the goal type, calculate below_target_percent, target_lower_bound, above_target_percent, target_upper_bound,
  # doesn't this need to be in before_validation? and it seems like we need to get the calorie_goal which may not yet be persisted
  def calculate_target_parameters(assigned_attributes = {})
    assign_attributes(assigned_attributes)
    case goal_type.to_sym
    when CALORIES
      calculate_below_target_percent
      calculate_above_target_percent
      calculate_new_target_lower_bound
      calculate_new_target_upper_bound
      calculate_pct_calories
    when /calculated|dynamic/
      calculate_below_target_percent
      calculate_above_target_percent
      case goal_type.to_sym
      when DYNAMIC_RANGE, CALCULATED_RANGE
        calculate_pct_calories

        # I didn't use nutrient.rounded_amount here, I wasn't sure if the fractional parts of goals matter.  Say your goal is 11.1 grams and you eat 11 - you haven't met the goal, but if we round, the goal would become 11
        # => TODO: calorie goal here needs to take into account meal calorie goals if we're a meal based goal
        calculate_amount
        calculate_new_target_lower_bound
        calculate_new_target_upper_bound
      when DYNAMIC_MAXIMUM, DYNAMIC_MINIMUM, CALCULATED_MAXIMUM, CALCULATED_MINIMUM
        # I didn't use nutrient.rounded_amount here, I wasn't sure if the fractional parts of goals matter.  Say your goal is 11.1 grams and you eat 11 - you haven't met the goal, but if we round, the goal would become 11
        calculate_amount
        calculate_new_target_lower_bound
        calculate_new_target_upper_bound
      end
    when MINIMUM_WITH_UPPER_LIMIT, MAXIMUM_WITH_INVISIBLE_LOWER_LIMIT
      calculate_new_target_lower_bound(amount)
      calculate_new_target_upper_bound(upper_limit)
    when MAXIMUM
      calculate_new_target_lower_bound(0)
      calculate_new_target_upper_bound(amount)
    when MINIMUM
      calculate_new_target_lower_bound(amount)
      calculate_new_target_upper_bound(amount)
    when RANGE
      calculate_new_below_target_percent
      calculate_new_above_target_percent
      calculate_amount
      calculate_pct_calories
    else
      raise "unknown goal type '#{goal_type}'"
    end
    self
  end

  # extracting calculations out into their own methods so that they can be used in other parts
  # of the codebase for individual calculations and to DRY out calculate_target_parameters a bit.
  # Especially useful for prepopulating values in various goal editing forms

  def calculate_below_target_percent
    self.below_target_percent ||= nutrient.default_target_pct_range.first
  end

  def calculate_above_target_percent
    self.above_target_percent ||= nutrient.default_target_pct_range.last
  end

  def calculate_new_target_upper_bound(new_value = nil, save_value = false)
    recalculate_upper_or_lower_parameter(:target_upper_bound, :above_target_percent, new_value, save_value)
  end

  def calculate_new_target_lower_bound(new_value = nil, save_value = false)
    recalculate_upper_or_lower_parameter(:target_lower_bound, :below_target_percent, new_value, save_value)
  end

  def calculate_new_below_target_percent(new_value = nil, save_value = false)
    recalculate_upper_or_lower_parameter(:below_target_percent, :target_lower_bound, new_value, save_value)
  end

  def calculate_new_above_target_percent(new_value = nil, save_value = false)
    recalculate_upper_or_lower_parameter(:above_target_percent, :target_upper_bound, new_value, save_value)
  end

  def variable_bound_calculation
    return unless [DYNAMIC_MAXIMUM, DYNAMIC_MINIMUM, CALCULATED_MAXIMUM, CALCULATED_MINIMUM, CALORIES, DYNAMIC_RANGE, CALCULATED_RANGE].include?(goal_type.to_sym)
    variable_calculation = case goal_type.to_sym
    when DYNAMIC_RANGE, CALCULATED_RANGE
      calorie_goal
    when CALORIES
      amount
    else
      calculate_pct_calories*calorie_goal
    end
    variable_calculation
  end

  def recalculate_upper_or_lower_parameter(attr_setter, calc_dependent_attr, new_value = nil, save_value = false)
    if new_value.nil?
      return unless val = self.send(calc_dependent_attr)
      new_value = (val * calories_conversion_factor / calorie_goal).round(2) if goal_type.to_sym == RANGE && calories_conversion_factor
      new_value = val  if goal_type.to_sym == RANGE && calories_conversion_factor.nil?
      new_value ||= (val*variable_bound_calculation / calories_conversion_factor) if attr_setter.to_s.include?("bound")
      # happens if the calorie goal is 0.0, which can happen for meal based goals. this doesn't matter, as the value
      # is never used in this case, however it is preventing indexing of the goals on AWS ElasticSearch, as they don't
      # follow the JSON spec and allow Infinity,, -Infinity, or NaN in their JSON.
      new_value = 0.0 if new_value.infinite?
    end
    self.send("#{attr_setter}=", new_value)
    self.save! if save_value
    self.send(attr_setter)
  end

  def calculate_new_amount(new_value = nil, save_value = false)
    new_value ||= calculate_amount
    self.amount = new_value
    self.save! if save_value
    self.amount
  end

  def variable_amount_calculation
    if goal_type.to_sym == RANGE
      (target_lower_bound+target_upper_bound) / 2.0
    else
      ((calculate_pct_calories * calorie_goal) / calories_conversion_factor)
    end
  end

  def calculate_pct_calories
    self.pct_calories ||= case goal_type.to_sym
    when DYNAMIC_RANGE, CALCULATED_RANGE
      [self.below_target_percent, nutrient.default_pct_calories].max
    else
      nutrient.default_pct_calories
    end
  end

  def calculate_amount
    self.amount ||= variable_amount_calculation
  end

  def eating_pattern_for_meal
    return if self.daily?
    goal.pattern_for(meal_time_id)
  end

  def meal_goal?
    !!self.meal_goal
  end

  def meal_goal
    goal = self.meal_goals.detect{|mg| mg.meal_time_id == self.meal_time_id} if self.meal_goals?
    goal ? goal.proportion : false
  end

  def meal_goals
    self.goal.meal_goals
  end

  def meal_goals?
    self.meal_goals.any?
  end

  def eating_pattern_calorie_goal
    eating_pattern_for_meal ? eating_pattern_for_meal * goal.calorie_goal : goal.calorie_goal
  end

  # => return the calorie goal.  If we're a meal based goal, find the eating pattern, historical
  # average, or 30/30/30/10 breakdown from the goal.  this calculation allows new meal_goals
  # to be populated with useable data
  def calorie_goal
    calorie_goal_nutrient.nil?? (self.daily?? goal.calorie_goal : self.eating_pattern_calorie_goal) : calorie_goal_nutrient.amount
  end

  def calorie_goal_nutrient
    goal.goal_nutrients.detect {|gsn| gsn.persisted? && gsn.nutrient_id == Nutrient.calories.id && gsn.meal_time_id == self.meal_time_id}
  end

  def period
    self.meal? ? self.meal_time_name : 'Daily'
  end

  def index
    meal_time_id.to_i
  end

  def weekly_scoped?
    daily? && attached_goal_weight_nutrients.any?{|gwsn| gwsn.multi_day?}
  end

  def daily_scoped?
    daily? && attached_goal_weight_nutrients.any?{|gwsn| gwsn.daily?}
  end

  def daily_and_weekly?
    daily_scoped? && weekly_scoped?
  end

  def goal_weight
    goal.goal_weight
  end

  def goal_weight_nutrients
    goal_weight.goal_weight_nutrients
  end

  def attached_goal_weight_nutrients
    goal_weight_nutrients.select{|gwsn| gwsn.nutrient_id == self.nutrient_id}
  end

  def actual_weekly_gsn?
    self.possible_weekly_gsn? && self.weekly_scoped?
  end

  def possible_weekly_gsn?
    self.nutrient_id.in?(Nutrient.possible_weekly_nutrient_ids) && self.daily?
  end

  private
  def range_but_not_calories?
    !calories? && goal_type.to_s.include?("range")
  end

  def calorie_range
    if self.calories?
      period_display = self.period
      below = self.below_target_percent.presence
      above = self.above_target_percent.presence
      if above && above < 1.0
        self.errors.add(:above_target_percent, "#{period_display} upper range of buffer can't be less than 100%")
      end
      if below && below > 1.0
        self.errors.add(:below_target_percent, "#{period_display} lower range of buffer can't be greater than 100%")
      end
    end
  end

  def target_range
    return if self.goal_type == 'calories'
    below_method, above_method, descriptive_text = self.goal_type.to_s.include?("_range") ? [:below_target_percent, :above_target_percent, " range"] : [:target_lower_bound, :target_upper_bound, ""]
    period_display = self.period
    below = self.send(below_method).presence
    above = self.send(above_method).presence

    if (above && below) && above < below
      self.errors.add(below_method, "#{period_display} lower#{descriptive_text} can't be greater than #{period_display} upper#{descriptive_text}")
    end
  end
end

