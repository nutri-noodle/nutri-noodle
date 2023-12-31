class Message < ApplicationRecord
  include ActionView::RecordIdentifier

  default_scope { order(created_at: :asc) }

  enum role: { system: 0, assistant: 10, user: 20 }

  belongs_to :user

# explanation - since it took literally 2 days to understand this code:
#
# the first (unnamed) parameter is the stream name. the stream name is
#   global across the system, so you need to scope it to the user if you
#   don't want to share data across all users.
# target: parameter is the id of the div in the HTML
#   I suppose it is unique to the page, not the stream, so it probably
#   doesn't need to be scoped. unless it is automagically connected the stream
#   name by name;)
# important, each parameter can be either a proc (something that can be called),
# in which case it is invoked with an ActiveRelation (which is magically user.messages)
# or it is something else, in which case it is returned.

# you can reverse engineer the code here: https://github.com/hotwired/turbo-rails/blob/main/app/models/concerns/turbo/broadcastable.rb#L101

  broadcasts_to(->(messages) { messages.user.dom_id(messages.user, :messages) },
                target: ->(messages) { messages.user.dom_id(messages.user, :messages) })

  def self.for_openai(messages)
    messages.map { |message| { role: message.role, content: message.content } }
  end

  QUESTIONS = [
    'Can you recommend a recipe?',
    'Can you recommand a food?',
    'Give me a meal plan for 3 days',
    'Give me a shopping list',
  ]

  def matching_foods
    ActiveRecord::Base.connection.select_rows(%Q(
      WITH base as (
      select coalesce(foods.common_name, foods.display_name, foods.name) as name, foods.id as id from foods, messages
      where
      to_tsvector(messages.raw_content) @@ plainto_tsquery(coalesce(foods.common_name, foods.display_name, foods.name)) = true
      and messages.id = #{id})
      select name, max(id) from base
      group by name
      order by max(length(name)) desc
      limit 1000
      ))
  end

  # before_update :markup_content, if: ->(me) {me.assistant? && me.raw_content_changed?}
# CREATE INDEX food_names on foods USING GIN (to_tsvector('english', coalesce(foods.display_name, foods.name)));
  def markup_content
    self.content = raw_content.dup
    if /Ingredients:(?<ingredients>(.|\n)+)Instructions:/m =~ content
      marker = ingredients.dup
      matching_foods.each do |arr|
        (food_name, food_id) = arr
        str=<<~END
          <div data-controller="hovercard" data-hovercard-url-value="/food_hover/#{food_id}" data-action="mouseenter->hovercard#show mouseleave->hovercard#hide">
          <a href='#'>\\1 SCORE #{rand(50..100).round}</a></div>
        END
        ingredients.sub!(/\b(#{food_name})\b/i, str)
      end
      self.content[marker] = ingredients
    end
  end

  def markup_content_and_update
    ## why?? why the fuck do I have to save and reload in the content of a get_ai_response
    ## job??? otherwise content doesn't think it has changed, WTF?
    self.raw_content = content
    save!
    reload
    markup_content
    save!
  end
end
