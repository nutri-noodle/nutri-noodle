# it would be need to write this like an ActiveRecord module:
# -- for food
#  acts_as_allergen_container :allergy_container_text => 'food'
# -- for offered meals
#  acts_as_allergen_container :source => :suggested_meal, :allergen_container_text => 'meal'
# -- for suggestion meals
#  acts_as_allergen_container :allergy_container_text => 'meal', :postscript => 'and will not be included in suggestions'
module AllergenContainer
  def contains_allergen?(profile)
    profile.present? && allows_allergens? && allergen_source.present? && allergic_for?(profile)
  end

  def allergy_warning(profile, override = false)
    if contains_allergen?(profile) || override
      ['This', allergy_container, 'may contain', allergen_list(profile), allergy_warning_postscript(override)].compact.join(' ').squish + '.'
    else
      ''
    end
  end

  def allergic_for?(profile)
    profile.present? && has_allergens?(profile)
  end

  def has_allergens?(profile)
    profile.present? && allergens_for(profile).count > 0
  end

  # => does profile's allergen tags intersect this food's allergen tags?
  def allergens_for(profile)
    ((profile||Profile.new()).tags_to_exclude & (allergen_source||Food.new).tags).select(&:allergen?)
  end

  def allergen_list(profile)
    allergens_for(profile).map{|tag| tag.name.downcase}.sort.to_sentence
  end



  # food / meal
  def allergy_container
    allergen_source.class.to_s.demodulize.downcase
  end

  def _allergy_warning_postscript
    allergy_warning_postscript.blank?? '' : " #{allergy_warning_postscript}"
  end

  # Text you want to appear at the end of the warning
  def allergy_warning_postscript(override = false)
    nil
  end

  # This has to provide a list of tags
  def allergen_source
    self
  end

  def allows_allergens?
    true
  end
end
