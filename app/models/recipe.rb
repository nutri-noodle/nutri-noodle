class Recipe < Food
  has_many :recipe_steps, -> {order(:display_order, :id)},  :dependent => :destroy, :foreign_key => 'recipe_id'
  accepts_nested_attributes_for :recipe_steps, :allow_destroy => true, :reject_if => proc { |attributes| attributes['instruction'].blank? && attributes['id'].blank? }

  define_matching_vectors :matching_recipe_search, :column => ["foods.ingredients_vector", "foods.vector"]
  has_many :main_ingredients

  validates :recipe_yield, numericality: { :greater_than => 0, :message => "^Please tell us the yield of your recipe.  How many servings does it make?" }

  before_validation do
    self.serving_unit = 'serving' if serving_unit.blank?
  end

  def mark_viewed_by(participant)
    participant.viewed_foods.find_or_create_by(:food_id =>self.id) do
      participant.recommended_foods.where(:food_id => self.id).update_all(:updated_at => Time.now)
    end
  end

  def recipe?
    true
  end

  def was_combination?
    return @was_combination unless @was_combination.nil?

    if (self.new_record?)
      @was_combination = false
    else
      @was_combination = Food.find(self.id).combination?
    end

    @was_combination
  end

  def recipe_measurement
    set_measurements(nil) if @recipe_measurement.nil?
    @recipe_measurement
  end

  def serving_measurement
    set_measurements(nil) if @recipe_yield.nil?
    @serving_measurement
  end

  def recipe_yield
    set_measurements(nil) if @recipe_yield.nil?
    @recipe_yield
  end

  def recipe_yield=(value)
    value = value.to_f unless value.nil?
    set_measurements(value)
    self.recipe_yield
  end

  # if they change the serving unit from "cup" to "tsp", we get very confused b/c we think that wrong unit is generated, and we never update the generated measurements
  # correctly
  def catch_awkward_serving_unit_rename
    m = measurements.detect {|m| m.name == serving_unit}
    if m && m.generated?
      m.measurement_source_id = MeasurementSource::USDA # hacky, but we are currently not setting it, so it is defaulting to USDA
      get_serving_measurement.measurement_source_id = MeasurementSource::GENERATED if get_serving_measurement.name.downcase != m.name.downcase
    end
  end

  def get_recipe_measurement
    measurements.detect {|m| m.measurement_source_id != MeasurementSource::GENERATED && m.name == 'Recipe' }
  end
  def get_serving_measurement
    measurements.detect {|m| m.measurement_source_id != MeasurementSource::GENERATED && m.name != 'Recipe' }
  end

  def set_measurements(recipe_yield=nil)

    if (self.was_combination?)
      # converting from a combiantion, grab the measurement (look for the default?) and rename it to recipe
      @recipe_measurement = self.measurements.select{|m| m.measurement_source_id != MeasurementSource::GENERATED }.first
      @recipe_measurement.attributes = {:name => "Recipe", :default => false}
    else
      # special case if they converted from one measurement that we would generate to another measurement that we would generate
      catch_awkward_serving_unit_rename unless new_record?
      # otherwise, we are a new recipe, or we're doing an update - extract out the recipe and serving measurements
      @recipe_measurement =  get_recipe_measurement
      @serving_measurement =  get_serving_measurement
      recipe_yield ||= ((1.0 / @serving_measurement.multiplier)) if @serving_measurement #/
    end

    # We couldn't find a serving - build it
    if (@serving_measurement.nil?)
      recipe_yield ||= 1.0
      @serving_measurement = self.measurements.build(:name => "serving", :enabled => true, :default_amount => 1.0)
    end

    # Couldn't find a recipe measurement - build that one
    if (@recipe_measurement.nil?)
      @recipe_measurement = self.measurements.build(:name => "Recipe", :multiplier => 1.0, :enabled => true, :default_amount => 1.0)
    end

    @serving_measurement.attributes = {:default => true, :multiplier => 1.0 / recipe_yield, :name => self.serving_unit.blank? ? "serving" : self.serving_unit}

    @recipe_measurement.attributes = {:default => false}

    @recipe_yield = ((1.0 / @serving_measurement.multiplier).round(2)) #/
  end

  def logo(current_user)
    current_user&.organization&.logos&.image(:pdf) || 'app/assets/images/pdfLogo.jpg'
  end

  def shopping_list_breakdown(serving,scale_factor, participant)
    # opinion - folks are not going to be cooking fractional recipes. So round up to nearest the recipe yield
    number_recipes = (serving.multiplier * scale_factor / recipe_yield).ceil
    ingredients&.inject([]) do |acc, ingredient|
      acc.concat(ingredient.food.shopping_list_breakdown2(ingredient, number_recipes, participant))
    end || []
  end
  # assuming that if a recipe uses a recipe, that the subrecipe is appropriately scaled already.
  def shopping_list_breakdown2(serving,scale_factor, participant)
    ingredients&.inject([]) do |acc, ingredient|
      acc.concat(ingredient.food.shopping_list_breakdown2(ingredient, scale_factor, participant))
    end || []
  end

  def recipe_breakdown
    [self, *ingredients.map(&:food).map(&:recipe_breakdown).flatten]
  end

  def estimate_times
    tmp = (ingredients + recipe_steps).inject({max_time: 0, cooking_time: 0, active_time: 0 }) {|acc, val| acc.sum_with(val.estimate_times)}
    tmp[:active_time] = [tmp[:active_time],5].max
    { total_time: tmp[:active_time] + ([tmp[:max_time],tmp[:cooking_time]].max),
      active_time: tmp[:active_time]
    }
  end

  def self.api_query(params)
    params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
    filtered_records = all
    {
      :matching_recipe_search => params[:search].presence || params[:matching_recipe_search],
      :non_matching_recipe_search => params[:exclude].presence || params[:non_matching_recipe_search],
    }.each do |meth, term|
      filtered_records = filtered_records.send(meth, term) if term.present?
    end

    if params.has_key?(:with_images) && !params[:with_images].to_s.strip.empty?
      filtered_records = check_param_boolean(params[:with_images]) ? filtered_records.with_images : filtered_records.without_images
    end

    if params.has_key?(:with_instructions) && !params[:with_instructions].to_s.strip.empty?
      filtered_records = check_param_boolean(params[:with_instructions]) ? filtered_records.with_instructions : filtered_records.without_instructions
    end

    if meal_names = Array.wrap(params[:meal_times]).compact_blank.presence
      filtered_records = filtered_records.by_meal_time_ids(meal_names)
    end

    # these scopes: "by_main_ingredients", "by_dietary_preferences", "by_dietary_considerations", "by_meal_types", "exclude_by_main_ingredients", "exclude_by_allergens"
    Taggable::Methods::ClassMethods::TAG_METHODS.each do |type, fields|
      fields.each do |field|
        field_value = if type.to_s == 'by_any'
                        params["by_any_#{field}"]&.compact_blank.presence || params["any_#{field}"]&.compact_blank.presence
                      elsif type.to_s == "by"
                        params[field]&.compact_blank.presence || params["include_#{field}"]&.compact_blank.presence || params["by_#{field}"]
                      elsif type.to_s == "exclude_by"
                        if params[:restrictions].present? && field.to_s == 'allergens'
                          params[:restrictions]&.compact_blank.presence
                        else
                          params["exclude_#{field}"]&.compact_blank.presence || params["exclude_by_#{field}"]&.compact_blank.presence
                        end
                      end
        if field_value && Array.wrap(field_value).compact_blank.present?
          filtered_records = filtered_records.send("#{type}_#{field}", Array.wrap(field_value).compact_blank)
        end
      end
    end

    filtered_records
  end
end
