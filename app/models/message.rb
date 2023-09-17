class Message < ApplicationRecord
  include ActionView::RecordIdentifier

  default_scope { order(created_at: :asc) }

  enum role: { system: 0, assistant: 10, user: 20 }

  belongs_to :user

  after_update_commit -> { broadcast_replace_to "messages" }
  after_create_commit -> { broadcast_created }
  # after_update_commit -> { broadcast_updated }

  def broadcast_created
    broadcast_append_later_to(
      "messages",
      partial: "messages/message",
      locals: { message: self, scroll_to: true },
      target: "messages"
    )
  end

  def self.for_openai(messages)
    messages.map { |message| { role: message.role, content: message.content } }
  end
end
