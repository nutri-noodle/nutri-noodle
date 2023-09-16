class Food < ApplicationRecord
  include Searchable
  include RelatedMeasurements
  include Taggable
  include CookingTime
  include KetoTagging

  has_many :food_profile_scores
  has_many :food_allergens
  has_many :food_main_ingredients

  # adds utility methods for queries that find meal tags - by_main_ingredients, exclude_by_main_ingredients, by_dietary_preferences
  # exclude_by_allergens, by_meal_types, by_dietary_considerations
  # :with_tags and :omit_tags also use the underlying methods in Taggable for filtering by tags
  add_taggables :tag_class => FoodTag, :tag_association => :food_tags, :foreign_key => "food_id"

  auto_strip_attributes :notes, :name, :brand, :display_name

  scope :enabled, lambda { where(:enabled => true)}
  scope :upc, lambda {|upc_code| joins(:upc_codes).where(:upc_codes=>{:upc_code => upc_code})}


  scope :recipe_or_combination, lambda { enabled.where(:type => ['Recipe', 'Combination'])}
  scope :with_instructions, lambda {where("exists(select 1 from recipe_steps where recipe_steps.recipe_id = foods.id)")}
  scope :with_images, lambda {where("exists(select 1 from food_images where food_images.food_id = foods.id)")}
  scope :without_instructions, lambda {where("not exists(select 1 from recipe_steps where recipe_steps.recipe_id = foods.id)")}
  scope :without_images, lambda {where("not exists(select 1 from food_images where food_images.food_id = foods.id)")}

  has_many :available_meal_times, :class_name=>'FoodAvailableMealTime', :inverse_of => :food, :dependent => :destroy
  has_many :meal_times, :class_name => "MealTime", :through => :available_meal_times
  scope :by_meal_time_names, lambda {|meal_time_names|
    var_names = meal_time_names.map {|meal_time_name| MealTime.filtered_meal_name(meal_time_name)}
    joins(:available_meal_times=>:meal_time).where(:meal_times => {:name => var_names}).uniq
  }

  scope :available_meal_names, lambda {|meal_names|
    filtered_meal_names = Array.wrap(meal_names.presence).map {|meal_time_name| MealTime.filtered_meal_name(meal_time_name)}.presence
    where("exists(select 1 from food_available_meal_times, meal_times where foods.id = food_available_meal_times.food_id and meal_times.id = food_available_meal_times.meal_time_id and meal_times.name in (:meal_names))", meal_names: filtered_meal_names)
  }
  scope :by_meal_time_ids, lambda {|meal_time_ids|
    meal_times = Array.wrap(meal_time_ids)
    if meal_times.first.to_s.match(/\D/)
      available_meal_names(meal_times)
    else
      joins(:available_meal_times).where(:food_available_meal_times => {:meal_time_id => meal_time_ids})
    end
  }

  def find_available_meal_times(current_participant=nil)
    if available_meal_times.loaded?
      available_meal_times.map(&:meal_time).sort_by(&:id).map(&:name).join(", ")
    else
      meal_times.reorder(:id => :asc).map(&:name).join(", ")
    end
  end

  # generate a preloader hash for foods, recursively taking into account that recipes contain other foods
  def self.deep_preload_hash(associations, level=10)
    if(level.zero?)
      {:food => [:ingredients=>:measurement].concat(associations)}
    else
      {:food => [{:ingredients=> [:measurement, deep_preload_hash(associations, level-1)]}].concat(associations)}
    end
  end


  def water?
    id == self.class.water_id
  end

  def self.water_id
    @water_id ||= 54412
  end

  has_many :food_nutrients, -> {order(:nutrient_id)}, :dependent=>:destroy, :inverse_of => :food, :autosave=>true do
    def enabled
      joins(:nutrient).where(:nutrients=>{:enabled=>true})
    end

    def for_measurement(measurement=proxy_association.owner.default_measurement)
      enabled.map{|fn| FoodNutrient.new(:food_id=>fn.food.id, :nutrient_id=>fn.nutrient_id,:amount=>(measurement.multiplier * fn.amount))}
    end
  end

  def self.from_json(attributes)
    self.new(attributes.except("id","food_nutrients", "measurements","tags","ingredients")).tap do |obj|
      if attributes["measurements"]
        obj.measurements = attributes["measurements"].map {|attr| fn = Measurement.new(attr); fn.clear_changes_information; fn}
        obj.association(:measurements).loaded!
      end
      if attributes["tags"]
        obj.tags = attributes["tags"].map {|attr| fn = Tag.new(attr); fn.clear_changes_information; fn}
        obj.association(:tags).loaded!
        obj.association(:food_tags).loaded!
      end
      obj.food_nutrients = attributes["food_nutrients"].map {|attr| fn = FoodNutrient.new(attr); fn.clear_changes_information; fn}
      obj.association(:food_nutrients).loaded!
      obj.enabled_food_nutrients = attributes["food_nutrients"].map {|attr| fn = FoodNutrient.new(attr); fn.clear_changes_information; fn}
      obj.association(:enabled_food_nutrients).loaded!
      if calories = obj.food_nutrients.detect {|fn| fn.nutrient_id == Nutrient::NutrientIds::CALORIES}
        obj.build_calories_food_nutrient(calories.attributes)
      else
        obj.build_calories_food_nutrient(:nutrient_id => Nutrient::NutrientIds::CALORIES, :amount => 0)
      end

      # Ok, so eager loading the ingredients for recipes actually slows down the entire suggestions meal presentation.
      # The extra overhead of creating the foods and food nutrients in the recipes (and any recipes therein)
      # doesn't pay off. In production, the average time went from 2000ms to 4000ms, but hey, the active record time
      # went to zero ... So I'm just commenting this code out and leaving it as a crumb for some future guy.

      # obj.ingredients = attributes["ingredients"].map {|attr| Ingredient.from_json(attr) } if attributes["ingredients"]
      # obj.association(:ingredients).loaded!

      obj.association(:calories_food_nutrient).loaded!
      obj.write_attribute(:id, attributes["id"])
      # must assign id after assigning objects to the food_nutrients association, otherwise the act of touching the association
      # causes ActiveRecord to check the database for food_nutrients for the food - hitting the database, which we're
      # trying to avoid!
      # obj.id = attributes["id"]
      # ^^ actually, no, fuck you rails, if you have an id you just blindly fetch the associations when I reference them.
      # clearing the changes below doesn't stop it (but nor does it hurt)
      obj.clear_changes_information
      obj.instance_variable_set(:@new_record, false)
    end
  end

  before_save do
    # For overridden food nutrients:
    #  - mark ones now with blank values as deleted, so they will be recalculated
    #    from ingredients
    #  - mark a corersponding calculated value as deleted so there is not a
    #    uniqueness violation on insert of the overridden one
    # CODE-589
    self.food_nutrients.select(&:overridden?).each do |fn|
      if fn.amount.blank?
        fn.mark_for_destruction
      elsif !fn.marked_for_destruction?
        self.food_nutrients.select {|ofn| ofn.nutrient_id == fn.nutrient_id && !ofn.overridden}.each(&:mark_for_destruction)
      end
    end
  end

  has_one :calories_food_nutrient, -> {where(:nutrient_id => Nutrient::NutrientIds::CALORIES)}, :class_name => "FoodNutrient"

  has_many :enabled_food_nutrients, -> {order(:nutrient_id).includes(:nutrient).where(:nutrients => {:enabled => true})}, :class_name => "FoodNutrient", :inverse_of => :food

  # We have a few foods without calories
  def enabled_food_nutrients_guarnteed_to_have_calories
    if self.enabled_food_nutrients.detect {|n| n.nutrient_id == Nutrient::NutrientIds::CALORIES }.nil?
      self.enabled_food_nutrients.build(:nutrient_id => Nutrient::NutrientIds::CALORIES, :amount => 0)
    end
    self.enabled_food_nutrients
  end

  has_many :servings, :dependent=>:destroy
  has_many :meals, :through => :servings
  has_many :meal_plans, :through => :meals

  has_many :model_servings
  has_many :food_tags, :dependent=>:destroy, :inverse_of => :food do
    def allergens
      to_a.select(&:allergen?).uniq
    end
    def other
      where(:tag_id => Tag.other.pluck(:id))
    end
    def visible_for_foods
      joins(:tag).merge(Tag.visible_for_foods)
    end
  end
  # food_tags_visible_for_foods
  delegate :visible_for_foods, :to => :food_tags, :prefix => true

  has_many :tags, :through=>:food_tags do
    def visible_for_foods
      where(:visible_for_foods => true)
    end
  end
  has_many :tags_visible_for_foods, lambda { visible_for_foods }, :through => :food_tags, :source => :tag
  has_many :recipe_tagging_tags, lambda { recipe_tagging }, :through => :food_tags, :source => :tag
  has_many :main_ingredients, lambda { main_ingredients }, :through => :food_tags, :source => :tag
  has_many :dietary_preferences, lambda { dietary_preferences }, :through => :food_tags, :source => :tag
  has_many :meal_types, lambda { meal_types }, :through => :food_tags, :source => :tag
  has_many :allergens, lambda { allergens }, :through => :food_tags, :source => :tag
  has_many :dietary_considerations, lambda { dietary_considerations }, :through => :food_tags, :source => :tag

  has_many :ingredient_histories, :dependent => :destroy

  has_many :measurements, -> {where(:measurements => {:enabled => true})}, :dependent=>:destroy, :inverse_of => :food, :autosave=>true do
    def grams
      detect {|m|m.name == 'g'}
    end
    def ounces
      detect {|m|m.name == 'oz'}
    end
    def cup
      detect {|m|m.name == 'cup'}
    end
    def not_generated
      where("measurement_source_id is null or measurement_source_id != ?", MeasurementSource::GENERATED)
    end
    def matching(name)
      where(:name=>name).first
    end

  end
  has_many :participant_measurements, -> {where("measurements.measurement_source_id != ?",MeasurementSource::GENERATED)}, :class_name=>'Measurement'
  #has_one :default_measurement, :class_name=>'Measurement', :conditions=>["measurements.default = ?", true]

  has_many :ingredients, ->{order(:display_order, :id)},  :foreign_key=>:recipe_id, :dependent=>:destroy, :inverse_of => :recipe, :autosave=>true
  has_many :ingredients_tags, :through => :ingredients, :source => :tags do
    def allergens
      to_a.select(&:allergen?).uniq
    end
  end

  # has_ordered_collection :ingredients, :reindex_from => 1

  has_many :used_as_ingredients, :class_name => "Ingredient", :foreign_key=>:food_id, :dependent=>:destroy, :inverse_of=>:food
  has_many :used_in_recipes_or_combinations, :through=>:used_as_ingredients, :source=>:recipe
  has_many :food_histories, :dependent=>:destroy
  has_many :nutrients, :through=>:food_nutrients, :source=>:nutrient
  has_many :enabled_nutrients, -> {where({:nutrients=>{:enabled=>true}})}, :through=>:food_nutrients, :source=>:nutrient
  has_many :search_descriptors, :dependent=>:destroy, :inverse_of => :food

  delegate :name, :to => :participant, :prefix => true, :allow_nil => true
  has_one :user, :through => :participant

  has_many :food_images, :inverse_of => :food, :dependent => :destroy do
    def thumbnail
      enabled.order(Arel.sql("case when thumbnail=true then 0 else 1 end")).order(Arel.sql("id asc")).first
    end
  end

  has_one :thumbnail_image, -> {where(enabled: true, thumbnail: true).order(:id => :asc)}, :class_name => "FoodImage", :foreign_key => :food_id

  has_one :restaurant_section, :inverse_of => :food
  has_one :restaurant, :through => :restaurant_section

  def author
    self.participant.nil? ? '' : self.participant.name
  end

  def self.recipes_and_combinations
    where(:type=>['Recipe','Combination'])
  end
  def self.combinations
    where(:type=>['Combination'])
  end

  has_many :incorrect_nutrient_reports, :dependent => :destroy, :inverse_of => :food

  has_many :upc_codes, :dependent=>:destroy, :autosave=>true, :inverse_of=>:food

  concerning :Recommendations do
    included do
      has_many :recommended_foods, :inverse_of => :food
      has_many :recommendations, :through => :recommended_foods
      has_many :accepted_recommendations, :class_name => "RecommendedFood", :inverse_of => :became_food, :foreign_key => :became_food_id
      has_many :viewed_foods, :inverse_of => :food
    end

    def viewed_by?(participant)
      participant.viewed_food?(id)
    end
    # The most recently created Recommendation for this food and that participant.  May——— be nil

    def recommender(participant)
      @recommender ||= begin
        if recommendation_for?(participant)
          if participant.recommended_foods.loaded?
            participant.recommended_foods.select{|rf| rf.food_id == id}.last&.coach
          else
            participant.recommended_foods.includes(:coach).where(:food_id => id).order(:created_at).last&.coach
          end
        end
      end
    end
    private :recommender

    # I could have meta-programmed recommender_name, recommender_last_name, recommender_first_name
    def recommender_name(participant)
      recommender(participant)&.name
    end
    def recommender_first_name(participant)
      recommender(participant)&.first_name
    end
    def recommender_last_name(participant)
      recommender(participant)&.last_name
    end
    def recommender_short_name(participant)
       recommender(participant)&.short_name
    end
    def recommendation_for?(member)
      participant_id != member.id && member.recommended_food?(id)
    end

    def recommended_name_for_participant(participant)
      name + "-#{participant.user.first_name}"
    end
  end

  validates_presence_of :name
  validates_numericality_of :grams, :allow_nil => true
  validates_length_of :name, :maximum => 255
  validates_length_of :from, :maximum => 255
  validates_length_of :notes, :maximum => 1024

  validate :no_recursive_ingredients, :on => :update
  validate :at_least_one_ingredient

  accepts_nested_attributes_for :search_descriptors, :allow_destroy=>true,:reject_if => proc { |attributes| attributes['descriptor'].blank? || attributes['search_weight'].blank? }
  accepts_nested_attributes_for :food_tags, :allow_destroy => true
  accepts_nested_attributes_for :food_nutrients, :allow_destroy => true
  accepts_nested_attributes_for :ingredients, :allow_destroy => true
  accepts_nested_attributes_for :measurements, :allow_destroy => true
  accepts_nested_attributes_for :participant_measurements, :allow_destroy => true
  accepts_nested_attributes_for :food_images, :allow_destroy => true
  accepts_nested_attributes_for :upc_codes, :allow_destroy => true

  module SearchOptions
    def search
      (self[:search] || '').strip
    end

    def brand
      (self[:brand] || '').strip
    end

    def unbranded?
      ActiveRecord::Type::Boolean.new.cast((self[:unbranded] || false))
    end

    def branded?
      !self[:brand].blank?
    end

    def favorites?
      self[:participant].present? && has_search?
    end

    def has_search?
      !self.search.blank?
    end

    # searched for soemthing, but didn't specify a brand (or unbranded)
    def popular_results?
      self[:brand].nil? && self[:unbranded].nil? && !search.blank?
    end

    # maximum number of brands to be returned in the query.  Queries like "strawberries"
    # can return 1000s of brands (3510 when this was written) and thats "not good"[tm]
    # because the clients are slow to render that (or crash because of android limits
    # on the amount of memory a view can use in the background).  So this limits
    # the brands to only the most N popular brands.  500 so for many queries, no
    # practical difference would be seen.   See additional comments in matching_brands
    def max_brands
      self[:max_brands] || 500
    end

    def merge(other_hash)
      rslt = super
      rslt.with_indifferent_access.extend(SearchOptions)
    end
  end

  concerning :FoodSearchRules do
    included do
      scope :matching_search_or_id, lambda {|search|
        if /^\d+$/.match(search)
          return where("foods.id = :search", :search => search.to_i)
        end
        Food.matching_search(search)
      }
      scope :matching_search, lambda {|search|
        if search.nil? || search.strip.empty?
          where("1=0") #don't make this Food.none
        else
          where("vector @@ plainto_tsquery('food_search', ?) ", search)
        end
      }

      # should this trim?
      scope :unbranded, lambda {where("coalesce(brand, '') = ''")}

      # should this trim?
      scope :branded, lambda {|brand|
        where("lower(brand) ilike " + ActiveRecord::Base.connection.quote("%#{brand}%"))
      }

      scope :autocomplete_match, lambda { |search|
        where("(coalesce(foods.brand,'') || coalesce(case when foods.display_name = '' then null else foods.display_name end, foods.name)) ilike " + ActiveRecord::Base.connection.quote("%#{search}%"))
      }
      scope :matching_display_name, lambda {|display_name| where("lower(display_name) ilike " + ActiveRecord::Base.connection.quote("%#{display_name}%"))}
      scope :matching_common_name, lambda {|common_name| where("lower(common_name) ilike " + ActiveRecord::Base.connection.quote("%#{common_name}%"))}
      scope :not_matching_common_name, lambda {|common_name| where("lower(common_name) not ilike " + ActiveRecord::Base.connection.quote("%#{common_name}%"))}
      scope :no_common_name, lambda { |no_common_name| where("lower(common_name) = '' or common_name is null")}
      scope :any_common_name, lambda { |any_common_name| where("common_name is not null and common_name != '' ")}

      scope :no_display_name, lambda { |no_display_name| where("lower(display_name) = '' or display_name is null")}

      scope :gs_department, lambda {|gs_department| where("source_id = 7 and department ilike ?",gs_department)}
      scope :gs_major_category, lambda {|gs_major_category| where("source_id = 7 and major_category ilike ?",gs_major_category)}
      scope :gs_subcategory, lambda {|gs_subcategory| where("source_id = 7 and subcategory ilike ?",gs_subcategory)}

      scope :public_food, lambda {where("participant_id = 0 or participant_id is null")}

      scope :only_enabled, lambda {where(:enabled=>true)}

      scope :by_food_type, lambda {|type|
        Food.unscoped.pluck("distinct(type)").include?(type) ? where(:type => type) : all
      }

      scope :with_tags, lambda {|tag_ids|
        by_tag(tag_ids)
      }
      #reviewed for SQL injection
      scope :omit_tags, lambda {|tag_ids|
         exclude_by_tag(tag_ids)
      }
    end
  end


  concerning :FoodMaintenance do
    included do
      attr_accessor :updating_food_tags

      before_update :if => :will_save_change_to_serving_unit? do
        self.measurements.select(&:default).each {|m| m.name = self.serving_unit}
      end

      ## workaround for issue with Postgres unique index constraints, null values are ignored. So if you have the same name, both with a NULL brand, Postgres doesn't throw a uniqness voilation. Yuk.
      before_validation do
        self.brand ||= ''
      end

      before_validation :remove_empty_nutrients
      before_validation :delete_existing_empty_nutrients


      before_validation :strip_newlines

      before_save :check_nutrients_changed

      before_update :stash_search_terms
      after_update :update_search_terms

      after_save :recalculate_ingredients
      before_save :add_missing_measurements
      after_destroy :remove_search_terms
      after_save :compute_search_vector
      after_save :compute_ingredients_vector, :if => :recipe_or_combination?

      after_save :update_allergen_tags

      # this can't be in the observer - observer callbacks are invoked after the associations are destroyed
      before_destroy :touch_suggestions_meals, :prepend => true

      # expire caches of library meals used to make /api/suggestions_libraries/1711.json fast
      after_update :touch_suggestions_meals

      after_commit :make_sure_food_nutrients_are_unique
    end

    def make_sure_food_nutrients_are_unique
      result = ActiveRecord::Base.connection.execute(self.class.send(:sanitize_sql_array,
        [
          "delete from food_nutrients
          where food_id = :food_id AND id not in (
            select distinct
              last_value (id) over wnd as max_id
            from food_nutrients
            where food_id = :food_id
            window wnd as (
              partition by food_id, nutrient_id
              order by id asc
              ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
            )
          )",
          :food_id => self.id
        ]))

      if result.cmd_tuples > 0
        food_nutrients.reload
      end

    end


    def strip_newlines
      [:name, :brand, :common_name, :display_name].each do |field|
        unless self.send(field).nil?
          self.send("#{field}=", self.send(field).gsub(/\r\n/, ' ').gsub(/\r|\n/, ' '))
        end
      end

      true
    end
    def touch_suggestions_meals
      self.suggestions_meals.each(&:expire_caches)
    end

    def check_nutrients_changed
      @nutrients_changed=food_nutrients.detect(&:has_changes_to_save?).present?
      true
    end

    def delete_existing_empty_nutrients
      food_nutrients.select {|fn|fn.amount.blank? && !fn.new_record?}.map(&:mark_for_destruction)
    end

    def remove_empty_nutrients
      self.food_nutrients = food_nutrients.reject {|fn|fn.amount.blank? && fn.new_record?}
    end

    def recalculate_ingredients
      if food?
        update_recipes if @nutrients_changed
      else
        ingredients.reload
        nutr=ingredients.map(&:nutrients).map(&:to_a).flatten(1).group_by(&:first).map {|k,v| [k,v.map(&:second).sum] }.to_h
        ## update existing and remove old.
        changed = nil
        food_nutrients.each do |food_nutrient|
          # overridden nutrients are not changed by this calculation
          next if food_nutrient.overridden? && !food_nutrient.marked_for_destruction?
          next if food_nutrient.marked_for_destruction?

          if nutr.include?(food_nutrient.nutrient_id)
            if(food_nutrient.amount != nutr[food_nutrient.nutrient_id])
              changed=true
              food_nutrient.amount = nutr[food_nutrient.nutrient_id]
            end
          else
            changed=true
            food_nutrients.delete(food_nutrient)
          end
        end

        ## add new nutrients
        nutr.each_pair do |n,v|
          unless(self.food_nutrients.detect {|food_nutrient|food_nutrient.nutrient_id == n && !food_nutrient.marked_for_destruction?})
            self.food_nutrients.build(:nutrient_id=>n,:amount=>v,:food_id=>self.id)
            changed=true
          end
        end

        if (changed)
          # Bulk inserting foods will save time creating foods (32 round trips to insert food nutrients)
          # but it seemed to confuse active record and result in FK violations later.  I'm not sure
          # why, but it seemed it was trying to insert additional food nutrients
          # unless self.food_nutrients.detect{|fn| !fn.new_record?}
          #   FoodNutrient.import self.food_nutrients.to_a, :validate => false
          # else
            save!(:validate=>false)
            update_recipes
            update_meals
          # end
        end
      end

      true
    end



    def compute_search_vector
      if ActiveRecord::Base.connection.select_value("select count(*) > 0 from pg_ts_config where cfgname = 'food_search'")
        ActiveRecord::Base.connection.execute(self.class.send(:sanitize_sql_array, ["update foods set
        vector =
          to_tsvector('food_search', coalesce(foods.display_name, '')) ||
          to_tsvector('food_search', foods.name) ||
          to_tsvector('food_search', coalesce(foods.descriptors,'')) ||
          to_tsvector('food_search', coalesce(foods.brand,''))
        where
          foods.id = ?", self.id]))
      end
    end

    def compute_ingredients_vector
      ActiveRecord::Base.connection.execute(self.class.send(:sanitize_sql_array,
        ["update foods set ingredients_vector =
          setweight( to_tsvector( 'english', coalesce(foods.display_name, foods.name, '')), 'A') ||
          setweight( to_tsvector( 'english', (select coalesce(string_agg(coalesce(ingredients.alternate_name, foods.display_name, foods.name, ''), ' '), '')
            from foods as f1
              join ingredients on ingredients.food_id = f1.id
              join foods on foods.id = ingredients.recipe_id
            where foods.type = 'Recipe' and foods.id = :food_id)), 'B')
          where foods.id = :food_id", :food_id => self.id
        ]))
    end

    # update the recipes on the queue server, b/c this can be lengthy
    def update_recipes
      RecalculateRecipesRequestJob.perform_later(self.id)
    end

    class RecalculateRecipesRequestJob < ApplicationJob
      attr_accessor :id
      queue_as :default

      def perform(id)
        self.id = id
        food = Food.find_by_id(id)
        unless food.nil?
          food.used_in_recipes_or_combinations.find_each(:batch_size => 1) do |used_in|
            used_in.recalculate_ingredients
          end
        end
      end

      def display_name
        "Recalculate recipes using food: #{id}"
      end
    end

    def update_meals
      RecalculateMealNutrientsRequestJob.perform_later(self.id) 
    end

    class RecalculateMealNutrientsRequestJob < ApplicationJob
      attr_accessor :id
      queue_as :default

      def perform(id)
        self.id = id
        food = Food.find_by_id(id)
        unless food.nil?
          Meal.recalculate_nutrients(food.meals.where("served_at > ?", Date.current - 1.week).map(&:id))
        end
      end

      def display_name
        "Recalculate meal nutrients and start index runs after editing food: #{id}"
      end
    end

    # this is very similar to code in Suggestions::Meal
    def update_allergen_tags
      return unless combination? || recipe?

      computed_allergens = ingredients_tags.allergens

      allergens_to_keep = food_tags.allergens.map do |food_tag|
        if computed_allergens.include?(food_tag.tag)
          food_tag
        else
          food_tag.mark_for_destruction
          nil
        end
      end.compact

      (computed_allergens - allergens_to_keep.map(&:tag)).each do |new_tag|
        food_tags.build(:tag_id => new_tag.id)
      end

      # => delete first
      food_tags.where(:id => food_tags.select(&:marked_for_destruction?).map(&:id)).destroy_all
      # => then save the rest
      food_tags.each do |food_tag|
        food_tag.save
      end

    end


    class_methods do

      def add_search_vectors_where_missing
        ids = Food.enabled.where(:vector => nil).ids
        ids.each_slice(100) do |chunk|
          ActiveRecord::Base.connection.execute("update foods set
          vector =
            to_tsvector('food_search', coalesce(foods.display_name, '')) ||
            to_tsvector('food_search', foods.name) ||
            to_tsvector('food_search', coalesce(foods.descriptors,'')) ||
            to_tsvector('food_search', coalesce(foods.brand,''))
          where foods.id in (#{chunk.join(',')})
          ")
        end
      end

      # change this, you need to also change the after_save callback
      def reindex_tsearch
        if ActiveRecord::Base.connection.select_value("select count(*) > 0 from pg_ts_config where cfgname = 'food_search'")
          ActiveRecord::Base.connection.execute("update foods set
          vector =
            to_tsvector('food_search', coalesce(foods.display_name, '')) ||
            to_tsvector('food_search', foods.name) ||
            to_tsvector('food_search', coalesce(foods.descriptors,'')) ||
            to_tsvector('food_search', coalesce(foods.brand,''))
          ")
        end
      end
    end

    # an allergen tag has changed (added or removed)
    def allergens_changed
      return if updating_food_tags

      AllergenUpdateJob.perform_later(self.id)
      self.updating_food_tags = true
    end

    class AllergenUpdateJob < ApplicationJob
      attr_accessor :id
      queue_as :default
      
      def perform(id)
        self.id = id
        food = Food.find_by_id(id)
        return if food.nil?

        # update tags in recipes and combinations
        food.used_in_recipes_or_combinations.find_each(:batch_size => 10) do |recipe_or_combination|
          # recalculate allergen tags - which would queue more of these updates
          recipe_or_combination.update_allergen_tags
        end

        # update tags in suggestion meals
        food.suggestions_meals.find_each(:batch_size => 10) do |meal|
          meal.update_allergen_tags_and_save
        end
      end

      def display_name
        "Update allergen tags for food: #{id}"
      end
    end
  end


  def food_associations_to_copy
    [:food_nutrients,:food_tags,:measurements,:search_descriptors,:ingredients]
  end

  scope :used_in, lambda {|food_ids, source_ids|
    where("foods.id in
      (
        WITH RECURSIVE used_in_foods AS
        (
          SELECT foods.*
          FROM ingredients
            join foods on ingredients.recipe_id = foods.id
          WHERE
            ingredients.food_id in (:food_ids)
          and foods.source_id in (:source_ids)
          UNION ALL
          SELECT foods.*
          FROM ingredients
            join used_in_foods on used_in_foods.id = ingredients.food_id
            join foods on ingredients.recipe_id = foods.id
          and foods.source_id in (:source_ids)
        )
        select id from used_in_foods
        UNION ALL
        select id from foods
        where id in (:food_ids)
        and foods.source_id in (:source_ids)
      )", :food_ids => Array(food_ids), :source_ids => Array(source_ids))
    }


  concerning :FoodSharing do
    included do
      scope :ingredients_of, lambda {|food|
        where("foods.id in (
                WITH RECURSIVE ingredient_foods AS
                (
                  SELECT foods.*
                  FROM ingredients
                    join foods on ingredients.food_id = foods.id
                  WHERE
                    ingredients.recipe_id = :recipe_id
                  UNION ALL
                  SELECT foods.*
                  FROM ingredients
                    join ingredient_foods on ingredient_foods.id = ingredients.recipe_id
                    join foods on ingredients.food_id = foods.id
                )
                select id from ingredient_foods
                order by id)", :recipe_id => food.id)
      }
      def ingredient_foods
        Food.ingredients_of(self)
      end
    end

    # These foods must be shared along with this one
    def dependent_foods
      self.ingredient_foods.select{ |f| f.participant_id > 0 }
    end


    # Food that must be shared along with this one, that aren't already available
    def dependent_foods_not_available_to(other_participant)
      foods = self.dependent_foods
      available_food_ids = other_participant.received_foods.accepted.where(:food_id => foods.map(&:id)).where("became_food_id is not null").map(&:food_id)
      foods.reject {|f| available_food_ids.include?(f.id)}
    end

    def available_as_ingredient_to?(participant)
      return true unless self.source_id == Source::PRIVATE

      # include households?
      return self.participant_id == participant.id
    end
  end

  def nutrient_values_uncached
    Hash[*(food_nutrients.collect {|aaa| [aaa.nutrient_id, aaa.amount]}).flatten]
  end

  def nutrient_values
    @nutrient_values||=nutrient_values_uncached
  end

  def has_ingredients?
    return !self.ingredients.empty?
  end

  def recipe_or_combination?
    combination? || recipe?
  end

  def contains_recipe?
    (recipe? && recipe_yield > 1) || ingredients.detect {|ingredient|ingredient.food.contains_recipe?}
  end
  def combination?
    false
  end

  def recipe?
    false
  end

  def food?
    return !recipe_or_combination?
  end

  def search_name
    primary_name = display_name.blank?? name : display_name
    case
    when brand.blank? then primary_name
    when primary_name =~ /#{Regexp.escape(brand)}/i then primary_name
    else "#{primary_name} (#{brand})"
    end
  end

  def generated_name
    FoodNaming::Namer.name(self)
  end

  def pretty_name
    return display_name unless display_name.blank?
    name
  end


  # return any tags on this food, any parent tags
  # tags can have parents!! then we'd traverse up the hierarchy in a BOM manner
  # however, ingredients are not done this way - we simply copy the tags at creation time.
  def calculated_tags
    _t = tags
    tags.each do |t|
      if t.has_parent?
        _t += [t.parent]
      end
    end
    _t
  end

  def serving_grams
    if has_ingredients?
      gms=0
      ingredients.each do |i|
        # XXX BOGON ALERT: i.multiplier is produced by measurement_rules.rb: measurement_multiplier * serving_amount
        gms += ((i.food.grams || 0) * i.multiplier)
      end
      gms
    else
      grams
    end
  end

  def default_measurement
    measurements.detect(&:default?) || measurements.first || Measurement.new(:food=>self,:name=>"Serving",:default=>true,:multiplier=>1.0) ## last one is defensive coding against a food with no measurements, which shouldn't exist, but still do for a few foods in the test suite data. the test suite data needs updating
  end

  def set_default_measurement(measurement_id)
    unless measurements.find_by_id(measurement_id).nil?
      Food.transaction do
        measurements.map{|f| f.update(:default=>false) }
        measurements.where(:id=>measurement_id).first.update(:default=>true) unless measurements.where(:id=>measurement_id).first.nil?
      end
      reload
    end
  end


  # find the requested measurement, the last logged measurement for this meal time
  # the last logged measurement, or the default measurement along with
  # the requested serving amount, or the last logged serving amount or 1
  def default_measurement_and_serving(participant, requested_measurement_id = nil, requested_serving_amount = nil, meal_time_name = nil)
    meal_history = nil

    # a measurement might have been requested - look for that one first
    measurement = self.measurements.find_by_id(requested_measurement_id)
    if (measurement.nil? && participant.present?)
      # try to find a measurement that they might have logged
      meal_time = MealTime.find_by_var_name(meal_time_name) || MealTime.dinner! # dinner because you might log it for lunch or breakfast the next day :)
      meal_history = self.default_serving_size(participant.id,meal_time.id)
      measurement ||= meal_history.measurement unless meal_history.nil?
    end
    # still nothing? use the default measurement
    measurement ||= self.default_measurement

    serving_amount = requested_serving_amount.fraction_to_float unless requested_serving_amount.nil?
    serving_amount = meal_history.serving_amount if !meal_history.nil? && (serving_amount.nil? || serving_amount == 0)

    serving_amount ||= measurement.default_amount
    serving_amount ||= 1

    serving_amount = 1 if serving_amount <= 0
    serving_amount = serving_amount.round if serving_amount.round == serving_amount # drop a .0

    [measurement, serving_amount]
  end

  def calories
    _efficient_nutrient_amount(Nutrient::NutrientIds::CALORIES)
  end

  def carbohydrates
    _efficient_nutrient_amount(Nutrient::NutrientIds::CARBOHYDRATES)
  end

  def fiber
    _efficient_nutrient_amount(Nutrient::NutrientIds::FIBER)
  end

  def fat
    _efficient_nutrient_amount(Nutrient::NutrientIds::FAT)
  end

  def protein
    _efficient_nutrient_amount(Nutrient::NutrientIds::PROTEIN)
  end

  def _efficient_nutrient_amount(nutrient_id)
    (food_nutrients.detect {|fn| fn.nutrient_id == nutrient_id} || FoodNutrient.new(:amount => 0)).amount
  end

  def ensure_unique_name(_name = self.name)
    # ensure uniqueness of combination name.
    food_scope = [nil, 0].include?(participant_id) ? Food.recipes_and_combinations.public_food : participant.foods
    count = 0
    proposed_name = _name
    while(true)
      break if food_scope.where("lower(name) = lower(?)", self.name).empty?
      self.name = "#{proposed_name}-#{count+=1}"
    end
  end


  private

  def no_recursive_ingredients
    ActiveRecord::Associations::Preloader.new.preload(self, :ingredients => :food )
    ingreds = {
      self.id => self.ingredients.map{|i| i.food}
    }
    new_ingredients = ingreds.values.flatten.uniq.delete_if{ |f| ingreds.keys.include?(f.id) }
    while (new_ingredients.size > 0)
      ActiveRecord::Associations::Preloader.new.preload(new_ingredients, :ingredients => :food )

      new_ingredients.each do |food|
        ingreds[food.id] = food.ingredients.map{|i| i.food }
      end

      new_ingredients = ingreds.values.flatten.uniq.delete_if{ |f| ingreds.keys.include?(f.id) }
    end

    if (ingreds.values.flatten.uniq.map(&:id).include?(self.id))
      errors.add(:base, "This food includes itself as an ingredient")
    end
  end

  def at_least_one_ingredient
    return unless combination? || recipe?

    if (ingredients.reject(&:marked_for_destruction?).empty?)
      errors.add(:base, "Please add at least one ingredient")
    end
  end


  public

  def shopping_list_conversion(participant)
    # pick the participant specific conversion first, then the global
    # one.
    source_conversions.detect { |tmp| tmp.reason.to_s=="shopping_list" && tmp.participant_id==participant} ||
    source_conversions.detect { |tmp| tmp.reason.to_s=="shopping_list"}
  end

  def map_grocery_food(serving, participant)
    shopping_list_conversion(participant)&.convert(serving) || serving
  end

  # regular foods scale their serving simply by a scale factor, but more complex implementations for combinations and recipes.
  def shopping_list_breakdown(serving,scale_factor, participant)
    [map_grocery_food(Serving.new(:food=>self, :measurement=>serving.measurement, :serving_amount => serving.serving_amount * scale_factor), participant)]
  end
  alias_method :shopping_list_breakdown2, :shopping_list_breakdown
  def recipe_breakdown
    []
  end

  def estimate_times
    { total_time: 0, active_time: 0}
  end

  # This is one of the most terrifying queries I've every written.  This query
  # first finds all the foods used directly in suggestions meals by
  # looking into the public libraries and their meals, then going over to the
  # serving suggestions and getting the food ids.  The food ids and meals
  # get rolled up into a food id and array of meal ids they are used in.  Next
  # things get wild as we RECURSIVELY expand the ingredients, keeping track of
  # which meals those are used in, then, finally, we group by the food id
  # and combine the arrays of ingredients
  scope :in_cusine_public_libraries, lambda { |library_ids|
    libraries_clause = library_ids ? "and suggestions_libraries.id in (#{Array(library_ids).join(',')})" : ''

    joins("
      join (
        WITH RECURSIVE foods_in_libraries AS
        (
          -- Base query - all the foods used directly in libraries.  First get
          -- the public libraries
          with public_libraries as (
            select suggestions_libraries.id
            from suggestions_libraries
            where published = true
            and type = 'Suggestions::PublicLibrary'
            and category = 0
            #{libraries_clause}
          ),
          -- Then get all the public meals
          public_meals as (
            select distinct(suggestions_library_meals.meal_id)
            from public_libraries join
            suggestions_library_meals on suggestions_library_meals.library_id = public_libraries.id
          )
          -- Now join over to servings, group by the food id and aggregate the meals
          -- the foods were used into as an array of meal ids
          select
            -- Roll up the servings into their meals
            suggestions_servings.food_id,
            array_agg(suggestions_servings.meal_id) as meal_ids
          from public_meals
            join suggestions_servings on suggestions_servings.meal_id = public_meals.meal_id
          group by 1

          -- recursive query - keep expanding the ingredients list
          UNION ALL
          SELECT ingredients.food_id, foods_in_libraries.meal_ids
          FROM ingredients
            join foods_in_libraries on ingredients.recipe_id = foods_in_libraries.food_id
        )
        select food_id, array_agg(distinct meal_id order by meal_id) as meal_ids
        from foods_in_libraries, unnest(meal_ids) meal_id
        group by 1
      ) as in_cusine_public_libraries on in_cusine_public_libraries.food_id = foods.id
    ").select("foods.*, in_cusine_public_libraries.meal_ids as cuisine_meal_ids")
  }

  def compute_speed_tag
    estimated_times = self.estimate_times
    computed_tag = (combination? || recipe?) ? Tag.get_speed_tag(estimated_times) : nil

    ActiveRecord::Base.no_touching do
      self.with_lock do
        self.update_columns(
          :estimated_active_time => estimated_times[:active_time],
          :estimated_total_time  => estimated_times[:total_time]
        )
        self.tags = self.tags - Tag.speeds + Array(computed_tag)
      end
    end
  end

  after_save do
    if recipe? || combination?
      UpdateFoodSpeedTag.perform_later(self.id)
    end
  end
end
