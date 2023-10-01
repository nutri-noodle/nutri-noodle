class GetAiResponseJob < ApplicationJob
  def perform(user)
    call_openai(user: user)
  end

  private

  # def call_openai(user:)
  #   message =user.messages.create(role: "assistant", content: "boo")
  #   message.update(content: "the wagon goes to the goblin")
  # end
  def call_openai(user:)
    message = user.messages.create(role: "assistant", content: "")
    OpenAI::Client.new.chat(
      parameters: {
        model: "gpt-3.5-turbo",
        messages: user.profile.for_openai + Message.for_openai(user.messages),
        temperature: 0.1,
        stream: stream_proc(message: message)
      }
    )
  end

  def stream_proc(message:)
    proc do |chunk, _bytesize|
      new_content = chunk.dig("choices", 0, "delta", "content")
      completed = !chunk.dig("choices",0,"finish_reason").nil?
      if completed
        message.markup_content_and_update
      else
        message.update(content: (message.content||"") + new_content.gsub("\n","<br/>\n"))
      end
    end
  end
end
