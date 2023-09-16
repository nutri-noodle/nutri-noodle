class Nutrient < ApplicationRecord
  include MagicNutrientMethods

  default_scope -> {order(:display_order)}
  has_many :food_nutrients, :dependent=>:destroy, :inverse_of=>:nutrient
  has_many :foods, :through=>:food_nutrients
  has_one :nutrient_unit, -> {where(default: true)}, inverse_of: :nutrient

  NUTRIENT_CLASSES = ['Macronutrients', 'Vitamins', 'Minerals'].freeze

  NON_PERCENTAGE_BASED_GOAL_TYPES = %w{calories range maximum minimum maximum_with_invisible_lower_limit minimum_with_upper_limit }

  def self.enabled
    @@enabled||=Rails.cache.fetch("enabled)nutrients") do
      where(:enabled=>true).includes(:nutrient_unit).to_a
    end
  end

  def self.cached_nutrients
    @@cached_nutrients||=Rails.cache.fetch("cached_nutrients") do
      Hash[*(all.includes(:nutrient_unit).map {|a| [a.id, a]}.flatten)]
    end
  end

  # fetches a list of records in the order given by the first argument, which is expected to a list
  def self.ordered_fetch(names)
    enabled.select {|nnn|names.include?(nnn.name)}.sort {|a,b| names.index(a.name) <=> names.index(b.name)}
  end

  module NutrientIds
    CALORIES         =191
    PROTEIN          =192
    CARBOHYDRATES    =194
    FAT              =214
    SATURATED_FAT    =196
    TRANS_FAT        =384
    FIBER            =206
    SUGARS           =385
    ADDED_SUGARS     =386
    CHOLESTEROL      =213
    OMEGA_3          =220
    VITAMIN_A        =208
    VITAMIN_B1       =200
    VITAMIN_B2       =201
    VITAMIN_B3       =202
    PANTOTHENIC_ACID =210
    VITAMIN_B6       =207
    FOLATE           =209
    VITAMIN_B12      =217
    VITAMIN_C        =215
    VITAMIN_D        =219
    VITAMIN_E        =216
    VITAMIN_K        =218
    CALCIUM          =221
    COPPER           =205
    IRON             =195
    MAGNESIUM        =203
    MANGANESE        =211
    PHOSPHORUS       =199
    POTASSIUM        =197
    SELENIUM         =212
    SODIUM           =193
    ZINC             =204
    WATER            =198
  end

  # This duck-types nutrients with things that reference nutrients.  Then you
  # can have modules here, and there, that both work off of nutrient_id
  alias_method :nutrient_id, :id

  # Also duck-typing
  def nutrient
    self
  end


  validates_presence_of :name

  def macronutrient?
    nutrient_class == 'Macronutrients'
  end

  def mineral?
    nutrient_class == 'Minerals'
  end

  def vitamin?
    nutrient_class == 'Vitamins'
  end


  def self.shortened_display_names
    @@shortened_display_names ||= {
      191=>"Cal",
      192=>"Pro",
      194=>"Carb",
      214=>"Fat",
      196=>"Sat Fat",
      206=>"Fiber",
      213=>"Chol",
      220=>"ω-3",
      208=>"VitA",
      200=>"VitB1",
      201=>"VitB2",
      202=>"VitB3",
      210=>"panto",
      207=>"VitB6",
      217=>"VitB12",
      215=>"VitC",
      219=>"VitD",
      216=>"VitE",
      218=>"VitK",
      221=>"Ca",
      205=>"Cu",
      195=>"Fe",
      203=>"Mg",
      211=>"Mn",
      199=>"Phos",
      197=>"K+",
      212=>"Se",
      193=>"Na",
      204=>"Zn"
    }
  end


  def shortened_display_name
    self.class.shortened_display_names[id]
  end

  def label_name
    if self.name == "Vitamin B1"
      "#{self.name} (Thiamin)"
    elsif self.name == "Vitamin B2"
      "#{self.name} (Riboflavin)"
    elsif self.name == "Vitamin B3"
      "#{self.name} (Niacin)"
    else
      self.name
    end
  end

  def sub_nutrient?
    ["Saturated Fat", "Trans Fat", "Trans Fat(g)", "Fiber", "Sugars", "Added Sugars"].include?(self.name)
  end

  def non_percentage_based_goal_type?(conduit_goal_type = nil)
    return false unless conduit_goal_type.present? || self.default_goal_type.present?
    test_goal_type = conduit_goal_type.presence || self.default_goal_type
    test_goal_type.in?(NON_PERCENTAGE_BASED_GOAL_TYPES)
  end

  def formatted_name
    # create each formatted_name
    @formatted_name ||= name.underscore.tr(" ", "_")
  end

  def self.formatted_name_list
    # hash of nutrient_id keys and formatted_name values
    @@formatted_name_list ||= Hash[Nutrient.enabled.map{|nutrient| [nutrient.id, nutrient.formatted_name]}]
  end

  def self.formatted_names
    # array of the formatted names
    @@formatted_names ||= self.formatted_name_list.values
  end

  def self.deformatted_names
    # find the nutrient_ids from the names
    @@deformatted_names ||= self.formatted_name_list.invert
  end

  def self.find_formatted_name(name)
    # find the opposite of whatever you are looking for
    name.is_a?(String) ? self.deformatted_names[name] : self.formatted_name_list[name]
  end

  delegate :unit_name, :pretty_amount, :pretty_amount_clean, :rounded_amount, :round_to, :to_base_amount, :from_base_amount, to: :nutrient_unit
  def abbreviation_name
    unit_name
  end

  def rdi_amount_in_units
    nutrient_unit.rdi_amount
  end

  TARGET_TEXT_HASH = Hash['Calories'=>' ','Fat'=>' ','Saturated Fat'=>'no more than','Trans Fat(g)'=>'no more than','Cholesterol'=>'no more than','Sodium'=>'no more than','Carbohydrates'=>' ','Protein'=>' ']
  def self.target_text(nutrient)
    # => if its not in the hash, its "at least"
    text = TARGET_TEXT_HASH[nutrient.name]
    text.nil? ? "at least " : text + " "
  end

  # override dynamic finder to use cache
  def self.find_by_name_and_enabled(name, enabled)
    if enabled
      self.enabled.find { |x| name == x.name }
    else # do we care if this catches enabled=nil?
      cached_nutrients.each_value.find { |x| !x.enabled && name == x.name }
    end
  end

  def default_target_pct_range
    case
    when protein? then 0.10 .. 0.35
    when carbohydrates? then 0.45 .. 0.65
    when fat? then 0.20 .. 0.35
    when fiber?,saturated_fat?,added_sugars? then 1.0 .. 1.0
    else 0.95 .. 1.05
    end
  end

  def default_pct_calories
    case
    when calories? then 1.0
    when protein? then 0.15
    when carbohydrates? then 0.55
    when fat? then 0.3
    when saturated_fat? then 0.07
    when fiber? then 0.014
    when added_sugars? then 0.10
    end
  end

  def human_to_pct_conversion
    case
    when fiber? then 1000
    when saturated_fat? then 100
    end
  end

  def meal_based_goal_types
    goal_types.reject {|a| a =~/calculated/}
  end
end
