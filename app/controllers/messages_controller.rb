# app/controllers/messages_controller.rb
class MessagesController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :authenticate_user!

  def create
    @message = current_user.messages.create(message_params.merge(role: "user"))

    GetAiResponseJob.perform_later(current_user)

    respond_to do |format|
      format.turbo_stream
    end
  end

  def index
    @messages = current_user.messages
    respond_to do |format|
      format.turbo_stream
      format.html
    end
  end

  private

  def message_params
    params.require(:message).permit(:content)
  end
end
