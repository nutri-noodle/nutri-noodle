class Measurement < ApplicationRecord
  belongs_to :food, :inverse_of=>:measurements, :touch => true
  before_validation :standardize_abbreviation
  validates_presence_of :name, :food
  validates_numericality_of :multiplier
  validates_numericality_of [:minimum_amount, :increment_amount], :allow_nil => true

  # set a default name if the measurement was created with a blank name
  after_find do
    self.name = 'serving' if name.blank? && default? && food.present? && (food.recipe? || food.combination?)
  end

  ROUNDING_CHART = {
    "tsp"=> [Rational(1,8), Rational(1,4), Rational(1,2), Rational(3,4)],
    "tbsp"=> [Rational(1,2)],
    "cup"=>[Rational(1,8), Rational(1,4), Rational(1,3), Rational(3,8), Rational(1,2), Rational(5,8), Rational(2,3), Rational(3,4),Rational(7,8)],
    "lb"=>[Rational(1,4), Rational(1,3), Rational(1,2), Rational(2,3), Rational(3,4)],
    "oz"=>[Rational(1,2)],
    "fl oz"=>[Rational(1,2)],
    'serving'=>[Rational(1,2)],
    'cracker'=>[Rational(1,1)]
  }.with_indifferent_access

  def oz?
    id == self.class.oz_id
  end

  def self.oz_id
    @oz ||= 7765
  end

  def rounded(serving_amount)
    if(increment_amount)
      result = serving_amount.round_by( increment_amount)
    elsif(valid_increments = ROUNDING_CHART[name])
      result = serving_amount.round_by(*valid_increments)
    else
      result = serving_amount.round_by( 0.5)
    end
    result

  end

  def default_measurement_amounts(serving_amount)
    return if serving_amount.nil? || serving_amount.zero?

    self.minimum_amount ||=serving_amount *0.5
    self.increment_amount ||=serving_amount*0.5

    self.minimum_amount = serving_amount if (serving_amount < minimum_amount)
    self.increment_amount = serving_amount if (serving_amount < increment_amount)

    save! if changed?
  end

  def generated?
    measurement_source_id == MeasurementSource::GENERATED
  end

  attr_accessor :generated_from_name_with_number
  alias :generated_from_name_with_number? :generated_from_name_with_number

  def weight?
    RelatedMeasurements::WEIGHT_UNITS.keys.include? name
  end

  def standardize_abbreviation
      self.name=name.to_s.gsub(/\bgrams*|gms?|g\b/i,'g')
      self.name=name.to_s.gsub(/\bcups\b/i,'cup')
      self.name=name.to_s.gsub(/\bounces*\b/i,'oz')
      self.name=name.to_s.gsub(/\btablespoons?|tbsps?|tps\b/i,'tbsp')
      self.name=name.to_s.gsub(/\bteaspoons*|tsps?\b/i,'tsp')
      self.name=name.to_s.gsub(/\bpounds?|lbs?\b/i,'lb')
      self
  end

  def extract_number_from_name
    matchdata = name.match(/^\s*((?:(?:\d+) +)?(?:\d*(?:\.?\d+))(?:\/(?:\d+))?) *(\w.*) */)

    unless matchdata.nil?
      (number, pretty_name) = matchdata.captures
      number = number.fraction_to_float
      pretty_name = pretty_name.strip.downcase
    end
    [pretty_name || name, number || 1]
  end

  ABBREVIATIONS=['tsp','tbsp','g','fl oz','oz', 'small', 'medium', 'large']
  def pretty_amount(serving_amount)
    as_fraction = serving_amount.to_fraction
    if name =~ /^\d+$/ # exactly redisplay "n servings of 1 fiber pill as n fiber pill, not n 1 fiber pill". This is for the stupid case where someone named the measurement as "1"
      pretty_name = ''
      as_fraction = as_fraction * name.to_i
    elsif name !~ /,| / && !ABBREVIATIONS.include?(name) ## fencing off crazy measurement names like cup, sliced + abbreviations don't get pluralized
      pretty_name = case when as_fraction <= 1 then name else name.pluralize end
    else
      pretty_name = name
    end
    if (as_fraction.is_a?(Float))
      as_fraction = as_fraction.round(3)
    end
    "#{as_fraction.to_fractional_string} #{pretty_name}".strip
  end


  # replace the other measurements with this measurement it is used (provided it has been saved to the db)
  def replaces(*other_measurements)
    self.default = default || other_measurements.any?(&:default?)
    return if other_measurements.all?(&:new_record?) || other_measurements.empty? || new_record?
    [Suggestions::Serving, IncorrectNutrientReport, MealPlanFood, FoodTemplate::Alternative, Serving, MealHistory, FoodPreference, Ingredient, IngredientHistory, SentServing].each do |table|
      table.where(:measurement_id => other_measurements.map(&:id)).update_all(:measurement_id => id)
    end
    FoodConversion.where(:source_measurement_id => other_measurements.map(&:id)).update_all(:source_measurement_id => id)
    FoodConversion.where(:target_measurement_id => other_measurements.map(&:id)).update_all(:target_measurement_id => id)
  end

  # Inspects the schema to determine if this measurement might be used and provides
  # a warning to a curator that changing the measurement might have side affects
  #
  # This excludes the model_servings table as measurement_id is not indexed
  # on that table.  We used to have that index, but the index grew to 50 GB in
  # size as the model_servings table has a lot of inserts and deletes and not
  # a lot of maintenance.  Eventually, that index, and other indexes, caused the
  # database size to swell and the server to run out of disk space.  And there
  # is nothing quite as fun as having the database run out of disk space on a
  # weekend holiday.
  #
  # Note that model servings display if the measurement is deleted.
  #
  # @return [Boolean]
  def used?
    # Most likely tables first, exclude model_servings
    @@tables ||= ActiveRecord::Base.connection.select_values("
      SELECT table_name
      FROM information_schema.columns
      WHERE table_schema = 'public'
      AND column_name = 'measurement_id'
      and table_name not like 'temp%'
      and table_name <> 'model_servings'
      order by case table_name
      when 'servings' then 0
      when 'ingredients' then 1
      else 2
      end, table_name
    ").to_a

    # This could be done as a giant union statement
    @@tables.each do |table_name|
      exists =  ActiveRecord::Base.connection.select_values("select exists(select 1 from #{table_name} where measurement_id=#{self.id.to_i})")[0]
      return exists if exists
    end
    false
  end
end
