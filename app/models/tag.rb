class Tag < ApplicationRecord
  auto_strip_attributes :parent_tag_id

  # This works, they are the same in the test db as production.  Just never
  # change anything and we're GTG
  KOSHER          = 2354
  VEGAN           = 2359
  VEGETARIAN      = 2360

  EASY            = 2346
  FAMILY_FRIENDLY = 2379
  FOR_ONE_OR_TWO  = 2380
  MAKE_AHEAD      = 2383
  PACK_N_GO       = 2347
  SLOW_COOK       = 2382

  EGG=2113
  MILK=2112
  PEANUTS=2106
  TREENUTS=2107

  MEAL_INCLUDE_TAGS = [:meal_types, :main_ingredients, :dietary_preferences, :breakfast_categories, :lunch_categories]
  RECIPE_INCLUDE_TAGS = [:meal_types, :main_ingredients, :dietary_preferences, :dietary_considerations, :allergens]
  has_many :food_tags, :dependent=>:destroy, :inverse_of=>:tag
  has_many :foods, :through=>:food_tags
  belongs_to :parent, :class_name=>'Tag', :inverse_of=>:children, :foreign_key=>'parent_tag_id', optional: true
  delegate :name, :to => :parent, :allow_nil => true, :prefix => true
  has_many :children, :class_name=>'Tag', :inverse_of=>:parent, :foreign_key=>'parent_tag_id', :dependent => :destroy

  validates :name, :presence => true
  validate :not_own_parent

  scope :matching_search, lambda {|search|
    unless search.nil?
      if search.to_i > 0
        where("id = ?",search)
      else
        where("name ilike " + ActiveRecord::Base.connection.quote("%#{search.strip}%")) unless search.nil? || search.strip.empty?
      end
    end
  }

  scope :by_main_ingredient, lambda {|*search|
    widened_search(search.flatten(1), "lower(tags.name) ilike ", main_ingredients)
  }

  scope :food_allergens, lambda {|food_ids|
    allergens.
    joins(:food_tags).
    where("food_tags.food_id" => food_ids).
    uniq
  }
  #Reviewed for sql injection
  scope :ordered, lambda {|column|
    db_column = Tag.columns.detect {|c| c.name == column }
    if db_column.present?
      if (db_column.type == :string || db_column.type == :text)
        return order(Arel.sql("lower(#{column})"))
      else
        return order(Arel.sql("#{column}"))
      end
    end
  }

  def self.meal_plan_tags_from_food_list(ingredients)
    # get the meal plan tags that propagate from those recursive ingredients
    Tag.
      joins(:food_tags).
      where(:food_tags => {:food_id => ingredients}).
      where(:parent_tag_id => Tag.meal_plan_tag_id, :propagate => true).
      distinct
  end

  def self.candidate_food
    where(:id => 1246).first!
  end
  def candidate_food?
    id == 1246
  end

  USER_CONFIGURATION="user_configuration"
  def self.user_configuration_tag
    Tag.root_tags.where(name: USER_CONFIGURATION).first!
  end
  def self.user_configuration
    user_configuration_tag.children
  end

  def self.meal_plan_tag_id
    @@meal_plan_tag_id ||= Tag.root_tags.find_by_name("Meal Plan Tags").id
  end
  def self.meal_type_tag_id
    @@meal_type_tag_id ||= Tag.root_tags.find_by_name("Meal Type").id
  end

  def self.breakfast_category_tag_id
    @@breakfast_category_tag_id ||= Tag.root_tags.find_by_name("Breakfast Category").id
  end

  def self.lunch_category_tag_id
    @@lunch_category_tag_id ||= Tag.root_tags.find_by_name("Lunch Category").id
  end

  def self.cuisine_tag_id
    @@cuisine_tag_id ||= Tag.root_tags.find_by_name("Cuisine").id
  end
  def self.speed_tag_id
    @@speed_tag_id ||= Tag.root_tags.find_by_name("Speed Tags").id
  end

  scope :root_tags, lambda {where("parent_tag_id is null")}

  scope :non_root_tags, lambda {where.not(:parent_tag_id => [nil, 0])}

  scope :available, lambda {where.not(:source_id => 10).where(:available => true)}

  scope :visible_for_foods, lambda {where(:visible_for_foods => true)}

  scope :allergens, lambda {
    non_root_tags.where(:parent_tag_id => @@allergen ||= Tag.find_by_name("Allergens"))
  }

  scope :main_ingredients, lambda {
    non_root_tags.where(:parent_tag_id => @@main_ingredient ||=Tag.find_by_name("Main Ingredient"))
  }

  scope :meal_plan_tags, lambda {
    where(:parent_tag_id => Tag.meal_plan_tag_id)
  }

  scope :other, lambda {
    allergens = Tag.allergens.pluck(:id)

    other = Tag.where("tags.id not in (?)", Tag.visible_for_foods.pluck(:id))
    other = other.where("tags.id != ?", Tag.candidate_food.id)
    other = other.where("tags.id not in (?)", allergens) unless allergens.empty?
    other
  }

  scope :exercise, lambda {
    joins(:parent).where(:parents_tags=>{:name=>"Exercise Cautions"})
  }

  scope :dietary_considerations, lambda {
    joins(:parent).where(:parents_tags=>{:name=>"Dietary Consideration"})
  }

  scope :dietary_preferences, lambda {
    joins(:parent).where(:parents_tags=>{:name=>"Dietary Preference"})
  }

  scope :recipe_tagging, lambda {
    where(:parent_tag_id => recipe_tagging_parent_ids)
  }

  scope :meal_tagging, lambda {
    where(:parent_tag_id => meal_tagging_parent_ids)
  }

  scope :recipe_tagging_parents, lambda { where(:id => recipe_tagging_parent_ids) }

  def self.recipe_tagging_parent_ids
    RECIPE_INCLUDE_TAGS.flat_map{|tag_type| send(tag_type).pluck(:parent_tag_id)}.uniq
  end

  scope :meal_tagging_parents, lambda { where(:id => meal_tagging_parent_ids) }

  def self.meal_tagging_parent_ids
    MEAL_INCLUDE_TAGS.flat_map{|tag_type| send(tag_type).pluck(:parent_tag_id)}.uniq
  end

  scope :meal_types, lambda {
    non_root_tags.where(:parent_tag_id => Tag.meal_type_tag_id)
  }

  scope :breakfast_categories, lambda {
    non_root_tags.where(:parent_tag_id => Tag.breakfast_category_tag_id)
  }

  scope :lunch_categories, lambda {
    non_root_tags.where(:parent_tag_id => Tag.lunch_category_tag_id)
  }

  scope :speed, lambda { |speed|
    speeds.where(:name => speed)
  }
  scope :speeds, lambda {
    non_root_tags.where(:parent_tag_id => speed_tag_id)
  }

  SPEEDS = {
    quick: 'Quick',  #(<= 10 total time)
    not_quick_but_still_fast: '30 minutes or less', # (< 30 min total time && <= 10 min prep)
    reasonable: 'An Hour or less', # ( < 1 1/2 hours total time)
    slow: 'More than an hour' # ( > 1hr)
  }
  def self.get_speed_tag(time_estimate)
    case
    when time_estimate[:total_time] <= 10 then speed(:quick).first
    when time_estimate[:total_time] <= 30 && time_estimate[:active_time] <=10 then speed(:not_quick_but_still_fast).first
    when time_estimate[:total_time] <= 90 then speed(:reasonable).first
    else
     speed(:slow).first
   end
  end

  scope :cooking_day_meal, lambda {
    speeds.where(:name=>SPEEDS.slice(:slow, :reasonable).values)
  }

  scope :parent_tags, lambda {where(:id => pluck(:parent_tag_id).uniq)}

  scope :top_level_tags, -> { where(:parent_tag_id => [0, nil])}

  scope :top_level_food_tags, -> { top_level_tags.where.not(:name=> ["Exercise Cautions", "0 Workflow Tags"])}
  cattr_reader :per_page
  @@per_page = 25

  def name_with_parents
    if parent_tag_id.to_i > 0
      "#{name} / " + parent.name_with_parents
    else
      name
    end
  end

  # def self.tsearch_query(search_terms)
  #   words = sanitize(search_terms.scan(/\w+/) * "|")
  #   from("tags, plainto_tsquery('pg_catalog.english', #{words}) as q").
  #   where("to_tsvector('pg_catalog.english', name) @@ q").order("ts_rank_cd(to_tsvector, q) DESC")
  # end
  def self.tsearch_query(search_terms, existing_tags)
    where("to_tsvector('english', name) @@ plainto_tsquery('pg_catalog.english', ?)", search_terms).where(existing_tags.nil? ? nil : ["name not in (?)", existing_tags])
  end

  def lpmodel_id
    "#{name}-#{id}".sanitize
  end

  def has_parent?
    return parent.present?
  end

  def is_used?
    foods.count>0
  end

  def self.grouped_food_tags_for_select
    grouped_children_tags = preload(:children => [{:children => [{:children => [{:children => [:children, :parent]}, :parent]}, :parent]}, :parent]).top_level_food_tags.map(&:grouped_children)
    grouped_children_tags.map! do |heading, collection|
      if collection.present?
        children_of_heading, grand_children = collection.flatten.partition{|tag| tag.parent == heading}
        sorted_collection = grand_children.sort_by{|tag| [tag.parent.name, tag.name]}.unshift(children_of_heading.sort_by(&:name)).flatten
        parents = sorted_collection.map(&:parent).uniq
        grouped_sorted_collection = sorted_collection.reject{|t| parents.include?(t)}.group_by{|t| t.parent}.to_a.flatten
        [heading.name, grouped_sorted_collection.map{|tag| [tag.name_plus_annotation, tag.id]}]
      else
        [heading.name_plus_annotation, heading.id]
      end
    end
    standalone, grouped = grouped_children_tags.partition{|heading, collection| !collection.is_a?(Array)}
    grouped.unshift(["Standalone Tags", standalone])
    grouped
  end

  def grouped_children
    if children.present?
      [self, children.sort_by(&:name).flat_map(&:grouped_children)]
    else
      [self, []]
    end
  end

  def name_plus_annotation
    extra_annotation = self.allergen? ? ' > (Allergen)' : nil
    extra_annotation ||= self.parent ? " > (#{self.parent.name.strip.gsub(/^-/, "")})" : ''
    "#{self.name.gsub("-", "")} (#{self.id})#{extra_annotation}".strip
  end

  # 1043;"Accompaniments" 1048;"Candy" 1055;"Fats and Oils" 1058;"Cooking Ingredients" 1071;"Spices" 1114;"Alcohol and Related"
  DEFAULT_EXCLUDE_TAGS = ["Accompaniments", "Candy", "Fats and Oils", "Cooking Ingredients", "Spices", "Alcohol and Related"]
  def self.default_exclude_tags
    where(:name=>DEFAULT_EXCLUDE_TAGS, :source_id=>Source::PUBLIC)
  end

  def allergen?
    self.name == "Allergens" || (has_parent? && parent.allergen?)
  end

  def main_ingredient?
    self.name == "Main Ingredient" || (has_parent? && parent.main_ingredient?)
  end

  def dietary_preference?
    self.name == "Dietary Preference" || (has_parent? && parent.dietary_preference?)
  end

  def self.dietary_preference_root
    where(:name=>"Dietary Preference").first
  end


  def dietary_consideration?
    self.name == "Dietary Consideration" || (has_parent? && parent.dietary_consideration?)
  end

  def self.dietary_consideration_root
    where(:name=>"Dietary Consideration").first
  end

  def meal_type?
    self.name == "Meal Type" || (has_parent? && parent.meal_type?)
  end

  def breakfast_category?
    self.name == "Breakfast Category" || (has_parent? && parent.breakfast_category?)
  end

  def lunch_category?
    self.name == "Lunch Category" || (has_parent? && parent.lunch_category?)
  end

  def meal_plan_tag?
    self.name == "Meal Plan Tags" || (has_parent? && parent.meal_plan_tag?)
  end

  def cuisine_tag?
    self.name == "Cuisine" || (has_parent? && parent.cuisine_tag?)
  end

  def self.keto_tag
    dietary_preferences.where(name: 'Keto').first!
  end


  def speed_tag?
    id == Tag.speed_tag_id || !!(parent&.speed_tag?)
  end


  def acceptable_for_meal_tag?
    main_ingredient? || meal_type? || breakfast_category? || lunch_category? || meal_plan_tag? || cuisine_tag? || speed_tag?
  end

  def not_own_parent
    errors.add(:base, "Cannot be its own parent") if parent == self
  end

end

