module RelatedMeasurements

  # Make it smarter
  ActiveSupport::Inflector.inflections { |i|
    i.irregular 'olive', 'olives'
    i.irregular 'slice', 'slices'
    i.irregular 'clove', 'cloves'
    i.irregular 'cookie', 'cookies'
  }

  WEIGHT_UNITS = {
    'g' =>{:multiplier => 1, :default_amount=>100.0 },
    'oz' =>{:multiplier =>28.3495, :default_amount=>3.0 },
    'lb' =>{:multiplier =>28.3495 * 16, :default_amount=>0.5 },
  }

  VOLUME_UNITS = {
      'tsp' =>6.0,
      'tbsp' =>2.0,
      'fl oz' =>1.0,
      'cup' =>0.125,
      'ml' =>29.5735,
  }
  COOKING_UNITS = {
      'tsp' =>6.0,
      'tbsp' =>2.0,
      'oz' =>1.0,
      'cup' =>0.125,
  }
  BEVERAGE_UNITS = {
      'fl oz' =>1.0,
      'ml' =>29.5735
  }
  BEVERAGE_W_LITRE_UNITS = BEVERAGE_UNITS.merge('L' =>29.5735 / 1000)
  BEVERAGE_METRIC_UNITS = BEVERAGE_W_LITRE_UNITS.except('fl oz')
  ALCOHOLIC_BEVERAGE_UNITS = {
      'dram' => 8.0, # of whiskey (The dram (archaic spelling drachm) was historically both a coin and a weight)
      'tsp' =>6.0,
      'tbsp' =>2.0,
      'fl oz' =>1.0,
      'cup' =>0.125,
      'ml' =>29.5735,
  }

  COMMONLY_MEASURED_BY_CUPS=["Alcohol and Related", "Bouillon, Stock", "Carbonated Soft Drinks", "Chocolate Beverages", "Coffee and Related", "Creamers",
     "Dips", "Drinks", "Drinks", "Fats", "Food Service", "Fruit Juices and Nectars", "Gelatin", "Gravy",
      "Jellies, Jams, Preserves, Marmalades", "Margarine, Margarine Substitutes", "Milk and Related", "Oils",
       "Other Beverages", "Salad Dressings", "Sauces", "Shortening", "Soups, Condensed",
        "Soups, Mixes", "Soups, Ready-to-Serve", "Syrups", "Tea", "Vegetable Juices", "Yogurt"]

  BEVERAGE_W_LITRE_TAGS = ["Carbonated Soft Drinks", "Fruit Juices and Nectars"]
  BEVERAGE_TAGS= BEVERAGE_W_LITRE_TAGS.concat [
      # "Alcohol and Related", (want to allow a tsp of wine, 1/2 cup of wine in a recipe)
        "Chocolate Beverages", "Coffee and Related", "Drinks",
         "Other Beverages", "Tea", "Vegetable Juices"]
  ALCOHOLIC_BEVERAGE_TAGS = ["Alcohol and Related"]

  def standardize_abbreviations
    measurements.map(&:standardize_abbreviation)
  end

  def volume_measurements_commonly_used?
       tags.any?{|t|COMMONLY_MEASURED_BY_CUPS.include?(t.name)}
  end

  def non_alcoholic_beverage?
        tags.any?{|t|BEVERAGE_TAGS.include?(t.name)}
  end

  def beverage_w_litre?
        tags.any?{|t|BEVERAGE_W_LITRE_TAGS.include?(t.name)}
  end

  def alcoholic_beverage?
        tags.any?{|t|ALCOHOLIC_BEVERAGE_TAGS.include?(t.name)}
  end

  def volume_measurements?
    measurements.any? {|m| VOLUME_UNITS.keys.include?(m.name) }
  end

  # def reset
  #   measurements.delete_all
  #   measurements.create!(:name=>'gram', :multiplier=>0.03)
  #   measurements.create!(:name=>'tbsp', :multiplier=>0.5)
  #   measurements.create!(:name=>'oz', :multiplier=>1.16)
  #   add_missing_volume_measurements
  #   measurements.each {|m| puts "#{m.name}, #{m.multiplier}" };nil
  # end

  def add_missing_measurements
    standardize_abbreviations
    extract_numbers_from_measurements
    add_missing_weight_measurements
    add_missing_volume_measurements
    merge_duplicate_measurements
  end

  def merge_duplicate_measurements
    measurements.sort_by(&:name).chunk(&:name).each do |key, duplicates|
      duplicates.first.replaces(*duplicates[1..-1])
      measurements.destroy(*duplicates[1..-1])
    end
  end

  def add_missing_volume_measurements
    reference_units = VOLUME_UNITS
    reference_units = COOKING_UNITS if volume_measurements_commonly_used? && !volume_measurements? # I have 'oz', but non of the rest
    reference_units = BEVERAGE_UNITS if non_alcoholic_beverage?
    reference_units = BEVERAGE_W_LITRE_UNITS if beverage_w_litre?
    reference_units = ALCOHOLIC_BEVERAGE_UNITS if alcoholic_beverage?
    add_missing_volume_measurements_helper(reference_units)
  end

  def add_missing_volume_measurements_helper(reference_units)
    missing_units = reference_units.keys - measurements.map(&:name)
    base_unit = measurements.find {|m| reference_units.include?(m.name) && !m.generated?}
    return if base_unit.nil? ## can't do much if we can't find the base unit    puts "base_unit #{base_unit.name}"
    reference_units.keys.each do |unit|
      multiplier = base_unit.multiplier * reference_units[base_unit.name].to_f / reference_units[unit].to_f
      measurement = measurements.detect {|m| m.name == unit}
      case
      when measurement.nil? then measurements.build(:name => unit, :multiplier => multiplier, :measurement_source_id=>MeasurementSource::GENERATED, :default_amount=>1) unless unit == 'fl oz' ## 'fl oz' just not safe => too often they have weight measurements with "cup"
      when measurement.generated?  && !measurement.generated_from_name_with_number? then measurement.assign_attributes(:multiplier => multiplier)
      end
    end
  end

  def add_missing_weight_measurements
    unless grams.nil? || grams.zero?
      missing_units = WEIGHT_UNITS.keys - measurements.map(&:name)
      WEIGHT_UNITS.keys.each do |unit|
        measurement = measurements.detect {|m| m.name == unit}
        multiplier = WEIGHT_UNITS[unit][:multiplier] / grams
        case
          when measurement.nil? then measurements.build(:name => unit, :multiplier => multiplier, :measurement_source_id=>MeasurementSource::GENERATED, :default_amount=>WEIGHT_UNITS[unit][:default_amount])
          when measurement.generated? && !measurement.generated_from_name_with_number? then measurement.assign_attributes(:multiplier => multiplier)
        end
      end
    end
  end

  def extract_numbers_from_measurements
    measurements.to_a.each do |measurement|
      matchdata = measurement.name.match(/^\s*((?:(?:\d+) +)?(?:\d*(?:\.?\d+))(?:\/(?:\d+))? )(\w.*) */)
      next if matchdata.nil?
      (number, name) = matchdata.captures
      number = number.fraction_to_float
      name = name.strip.downcase
      # create new one if needed. Special case if the number is 1, just remove the "1" from the existing measurment and reuse it.
      if number == 1.0
        measurement.name = name
        measurement.default_amount = number
      else
        name=name.singularize
        existing_measurement = measurements.detect {|m| m.name == name}
        case
        when existing_measurement.nil? then measurement=measurements.build(:name=>name, :multiplier=>measurement.multiplier/number, :measurement_source_id=>MeasurementSource::GENERATED, :default_amount=>number);measurement.generated_from_name_with_number=true
        when existing_measurement.generated? then existing_measurement.generated_from_name_with_number=true; existing_measurement.assign_attributes(:multiplier=>measurement.multiplier/number, :measurement_source_id=>MeasurementSource::GENERATED)
        end
      end
    end
  end
end
