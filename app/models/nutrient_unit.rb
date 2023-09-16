class NutrientUnit < ApplicationRecord
  belongs_to :nutrient

  # Nutrient units convert from the base units for the food into display units
  #
  # As I write this in Nov 2021, display units and base units are identical for all
  # nutrients except Vitiman D, which has base units of UI and display units of mcg.
  #
  # However, in a future world, you could see there being multiple display units corresponding to
  # different localizations.
  #
  # Addition, nutrient_units allow us to store all the food nutrients in a display independant manner,
  # insulating the database and various caches (ElasticCache, ElasticSearch) from the display changes.
  # This is important, as refreshing those caches for all foods, all meals, etc takes literally weeks of
  # runtime and baby-sitting.

  def rdi_amount
    nutrient.rdi_amount.nil?? nil : (nutrient.rdi_amount * multiplier)
  end

  alias_attribute :unit_name, :abbreviation_name

  # pretty amount /w the units.
  # The amount is in base units and is converted to user display units, unless 1.0 is passed as the multiplier
  def pretty_amount(amount, fred=multiplier)
    pretty_amount_clean(amount, fred) + ' ' + abbreviation_name unless amount.nil?
  end

  # The amount is in base units and is converted to user display units, unless 1.0 is passed as the multiplier
  def pretty_amount_clean(amount, fred=multiplier)
    unless amount.nil?
      number_with_delimiter((amount*fred).round(round_to).to_s)
    end
  end

  def to_base_amount(amount)
    (amount.to_f/multiplier)
  end

  def from_base_amount(amount)
    (amount*multiplier)
  end

  # The amount is in base units and is converted to user display units
  def rounded_amount(amount)
    unless amount.nil?
      from_base_amount(amount).round(round_to)
    end
  end

  def number_with_delimiter(number, delimiter=",", separator=".")
    parts = number.to_s.split('.')
    parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}")
    parts.join separator
  end

end
