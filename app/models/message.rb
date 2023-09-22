class Message < ApplicationRecord
  include ActionView::RecordIdentifier

  default_scope { order(created_at: :asc) }

  enum role: { system: 0, assistant: 10, user: 20 }

  belongs_to :user

  broadcasts_to(->(messages) { messages.user.dom_id(messages.user, :messages) },
                target: ->(messages) { messages.user.dom_id(messages.user, :messages) })

  def self.for_openai(messages)
    messages.map { |message| { role: message.role, content: message.content } }
  end
end
