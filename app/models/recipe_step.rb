class RecipeStep < ApplicationRecord
  belongs_to :recipe, :foreign_key => 'recipe_id', :touch => true

  validates_presence_of :instruction
  validates_numericality_of :display_order, :greater_than => 0, :only_integer => true

  auto_strip_attributes :instruction, :squish => false

  def extract_time(sentence)
    tmp = ChronicDuration.parse(sentence)
    case
    when tmp
      tmp / 60
    when sentence =~ /until al dente/
      10
    when sentence =~ /until soft/
      5
    when sentence =~ /heat over .* heat/
      2
    when sentence =~ /whisk to combine/
      1
    else
      nil
    end
  end

  def estimate_time_helper(sentence)
    time = extract_time(sentence)
    result = if time.nil?
      {max_time: 0, cooking_time: 0, active_time: 2 }
    else
      case time
      when time < 15.minutes
        {max_time: 0, cooking_time: 0, active_time: time }
      when instruction =~ /meanwhile/i
        {max_time: time, cooking_time: 0, active_time: 0 }
      else
        {max_time: 0, cooking_time: time, active_time: 0 }
      end
    end
    result.merge(instruction =~ /sliced|diced|chopped|cubed|minced|peeled|grated/ ? {active_time: prep_scale_factor} : {active_time: 0})
  end

  def prep_scale_factor
    recipe.recipe_yield / 4.0
  end

  def sum_times(h1, h2)
    {
      cooking_time: h1[:cooking_time] + h2[:cooking_time],
      active_time: h1[:active_time] + h2[:active_time],
      max_time: [h1[:max_time],h2[:max_time]].max,
    }
  end

  def estimate_times
    instruction.split('.').map {|sentence|estimate_time_helper(sentence)}.inject {|acc, val| sum_times(acc, val)}
  end

end
