class Message < ApplicationRecord
  include ActionView::RecordIdentifier

  default_scope { order(created_at: :asc) }

  enum role: { system: 0, assistant: 10, user: 20 }

  belongs_to :user

# explanation - since it took literally 2 days to understand this code:
#
# the first (unnamed) parameter is the stream name.
# target: parameter is the id of the div in the HTML
# important, each parameter can be either a proc (something that can be called),
# in which case it is invoked with an ActiveRelation (which is magically user.messages)
# or it is something else, in which case it is returned.

# you can reverse engineer the code here: https://github.com/hotwired/turbo-rails/blob/main/app/models/concerns/turbo/broadcastable.rb#L101

  broadcasts_to(->(messages) { messages.user.dom_id(messages.user, :messages) },
                target: ->(messages) { messages.user.dom_id(messages.user, :messages) })

  def self.for_openai(messages)
    messages.map { |message| { role: message.role, content: message.content } }
  end
end
