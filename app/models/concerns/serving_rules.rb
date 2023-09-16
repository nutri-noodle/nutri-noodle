module ServingRules
  extend ActiveSupport::Concern
  included do
    delegate :ingredients, :to => :food
  end

  def preload_measurements
    if respond_to?("_reflections") && self._reflections.keys.include?("measurement") && !association(:measurement).loaded?
      ActiveRecord::Associations::Preloader.new.preload(self, [:measurement])
    end
    if respond_to?("_reflections") && self._reflections.keys.include?("measurements") && !association(:measurements).loaded?
      ActiveRecord::Associations::Preloader.new.preload(self, [:measurements])
    end
  end

  def ingredients_scaled
    @ingredients_scaled ||= ingredients.map do |ingredient|
      i = ingredient.deep_clone :include => [{:food => :measurements}, :measurement]
      i.serving_amount = i.serving_amount * serving_amount * measurement_multiplier
      i
    end
  end


  def nutrient_amounts
    # warning: multiplier is serving_amount * measurement_multiplier
    Hash[*food.enabled_food_nutrients.map {|fn| [fn.nutrient, fn.rounded_amount(multiplier)]}.flatten]
  end

  # Get a hash of nutrient => rounded amounts in this serving for all the macro nutrients
  #---
  # Note: carefully chosen to not include omega-3
  def macronutrient_amounts
    nutrient_amounts.select {|nutrient, amount| nutrient.macronutrients? }
  end

  def macronutrient_amounts_objects
    macronutrient_amounts.map do |nutrient, amount|
      OpenStruct.new.tap do |obj|
        obj.nutrient_id = nutrient.id
        obj.amount = amount
        obj.units = nutrient.unit_name
        obj.name = nutrient.name
      end
    end
  end

  def raw_measurement=(value)
    @raw_measurement ||= value
  end
  def raw_measurement
    @raw_measurement
  end
  def raw_measurement_name
    @raw_measurement.present? ? @raw_measurement.name : ''
  end
  def raw_measurement_id
    @raw_measurement.present? ? @raw_measurement.id : nil
  end

  def raw_serving_amount=(value)
    @raw_serving_amount ||=value
  end
  def raw_serving_amount
    @raw_serving_amount
  end

  def food_name(pretty = true)
    # pretty_name - doesn't include brand, search_name includes brand in params
    default = food.present? ? pretty ? food.pretty_name : food.search_name : ''

    if self.respond_to?(:alternate_name)
      alternate_name.blank? ? default : alternate_name
    else
      default
    end
  end

  def food_measurements
    food.present? ? food.measurements : Measurement.where("1=0")
  end

  def fractional_serving_amount
    (self[:serving_amount]||0).to_fractional_string
  end

  def fractional_serving_amount=(amount)
    self[:serving_amount] =  amount.is_a?(String) ? amount.fraction_to_float : amount
  end

  def normalize_measurement_for_embedded_number
    return if measurement.nil?

    # first, deal with something like "2" of "1/2 oz" by normalizing to "1 oz"
    (pretty_name, number) = measurement.extract_number_from_name
    # return if pretty_name.split(" ").size > 2 # don't convert 1 "6 oz container" to 6 "oz container"

    amount = serving_amount * number
    preload_measurements
    new_measurement = nil
    new_measurement = food.measurements.find {|mmm| mmm.name.downcase == pretty_name.downcase}


    if new_measurement.nil? && number.to_i == number && number > 1
      # its a whole integer greater than 1, check for a pluralization match
     new_measurement = food.measurements.find {|measurement| measurement.name.downcase == pretty_name.downcase.singularize}
    end

    # You should always be able to find a version w/o the number in it, since the missing measurements code takes care of that (see extract_numbers_from_measurements)
    # But I'm paraniod, and at least do no harm
    unless new_measurement.nil?
      self.measurement = new_measurement
      self.serving_amount = amount
    end
  end

  # given the existing measurement, pick some other measurement if it is easier to understand, adjusting the serving amount as needed
  # if you save this serving, the new answer will be permanent
  MEASURING_SPOON_SIZES = {
    "tsp"=> [0, Rational(1,8), Rational(3,8), Rational(1,4), Rational(1,2), Rational(3,4),1],
    "tbsp"=> [0, Rational(1,2),1],
    "cup"=>[Rational(1,4), Rational(1,3), Rational(1,2), Rational(2,3), Rational(3,4),1],
    "lb"=>[Rational(1,4), Rational(1,3), Rational(1,2), Rational(2,3), Rational(3,4),1],
    "oz"=>[Rational(1,2),1],
    "fl oz"=>[Rational(1,2),1]
  }
  def rationalize_measurement(serving_factor=1)
    return if measurement.nil?
    self.raw_measurement = measurement
    self.raw_serving_amount = serving_amount * serving_factor

    normalize_measurement_for_embedded_number
    name_set = food.measurements.map(&:name)
    ## carefully arranged from most precise to least precise, find the best reference set of candidate measurements to convert between
    reference_set = [RelatedMeasurements::ALCOHOLIC_BEVERAGE_UNITS, RelatedMeasurements::BEVERAGE_METRIC_UNITS,(RelatedMeasurements::COOKING_UNITS.except('oz')),RelatedMeasurements::VOLUME_UNITS.except('fl oz')].detect do |set|
      name_set.size - (name_set - set.keys).size == set.size
    end
    unless reference_set.nil? || !reference_set.include?(measurement.name)
      candidates = food.measurements.select {|aaa| reference_set.include?(aaa.name)}
      best_measurement=nil
      ranked = candidates.collect do|candidate_measurement|
        tmp = (amount_in(candidate_measurement)*serving_factor).to_fraction
        tmp=tmp.round(1) if tmp.is_a?(Float)
        # display a preference for common measurement sizes that you can undoubtable measure in gesture. Ie. prefer 1/4 cup to 4 tbsp
        shortcuts = MEASURING_SPOON_SIZES[candidate_measurement.name]
        if(shortcuts.present? && shortcuts.include?(tmp))
          score = 0
        else
          tmp+=100 if tmp < 0.1 ## fencing off small numbers that round to effectively zero
          # special common units in the kitchen here
          if tmp.numerator > 100 || tmp.denominator > 100
            #if these aren't gonna be nice neat fractions, then compare the proposed new number
            #against the original number and prefer the smaller number, ie, prefer 1.3 vs 21.3
            # however, boost the score by 100 so that any reasonable natural fractions will win
            # instead
            score = 100 + tmp.floor - raw_serving_amount.floor
          else
            score = tmp.numerator + tmp.denominator
          end
        end
        # prefer the original measurement somewhat
        score +=((candidate_measurement == raw_measurement) ? 0 : 1)
        # puts "candidate_measurement=#{candidate_measurement.name} tmp=#{tmp} score=#{score}"
        [candidate_measurement, score]
      end
      ranked.sort_by(&:second).each do |candidate_measurement, distance|
        best_measurement=candidate_measurement
        break
      end
      if best_measurement != measurement
        self.serving_amount = amount_in(best_measurement)
        self.measurement = best_measurement
      end
    end
  end

  def pretty_amount_with_units(multiplier=1)
    preload_measurements
    if measurement.nil?
      # convert 1.0 to 1
      amt = (serving_amount.round == serving_amount ? serving_amount.round : serving_amount) * multiplier
      unit = amt > 1 ? 'Servings' : 'Serving'
      "#{amt} #{unit}"
    else
      rationalize_measurement(multiplier)
      measurement.pretty_amount(self.serving_amount * multiplier)
    end
  end

  def measurement_multiplier
    measurement.present? ? measurement.multiplier : 1
  end

  def multiplier
    measurement_multiplier * serving_amount
  end

  def measurement_name
     measurement.present? ?  measurement.name : 'serving'
  end

  def amount_in(other_measurement)
    serving_amount * measurement_multiplier / (other_measurement.nil?  ? 1 : other_measurement.multiplier)
  end

  def base_calories
    food.nil? ? 0 : food.calories
  end

  delegate :fiber, :carbohydrates, :to => :food, :allow_nil => true, :prefix => :base

  def calories
    base_calories * multiplier
  end

  def rounded_calories
    (calories || 0).round
  end

  def carbohydrates
    nutrient_in_serving(Nutrient.carbohydrates)
  end

  def fiber
    nutrient_in_serving(Nutrient.fiber)
  end

  def protein
    nutrient_in_serving(Nutrient.protein)
  end

  def fat
    nutrient_in_serving(Nutrient.fat)
  end

  def nutrient_in_serving(nutrient)
    ret = 0
    c = food.food_nutrients.detect { |fn| fn.nutrient_id == nutrient.id }
    ret = c.amount * multiplier unless c.nil?
    ret
  end

  def core_attributes
    attributes.slice("food_id","measurement_id","serving_amount")
  end

  def default_serving_amount_min
    serving_amount * ((food.tags.detect {|t| t.min_serving_factor.present?}&.min_serving_factor) || 0.5)
  end

  def default_serving_amount_max
    serving_amount * ((food.tags.detect {|t| t.max_serving_factor.present?}&.max_serving_factor) || 1.5)
  end

  module ClassMethods
    # sum a list of servings, maybe in the database, maybe not, and return the composite food nutrients
    # this will also work for ingredients - requirement is each object in the collection have:
    #  - serving_amount
    #  - measurement
    #  - food
    # returns an array of FoodNutrients
    def sum_nutrients(servings)
      nutrients = {}
      servings.each do |serving|

        # only sum enabled?
        if serving.food
          serving.food.enabled_food_nutrients.each do |food_nutrient|
            nutrients[food_nutrient.nutrient_id] ||= FoodNutrient.new(:amount => 0, :nutrient_id => food_nutrient.nutrient_id)

            nutrients[food_nutrient.nutrient_id].amount += food_nutrient.amount * serving.measurement.multiplier * serving.serving_amount
          end
        end
      end
      nutrients.values
    end
  end

  DUP_EXCLUDE_ATTRIBUTES = %w{id meal_id created_at updated_at}
  def dup?(other_serving)
    attributes.except(*DUP_EXCLUDE_ATTRIBUTES) == other_serving.attributes.except(*DUP_EXCLUDE_ATTRIBUTES)
  end

end
