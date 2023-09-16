# app/controllers/chats_controller.rb
class ChatsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_chat, only: %i[show]
  before_action :set_chats_collection, only: %i[index show]
  respond_to :html

  def show
    respond_with(@chat)
  end

  def create
    @chat = Chat.create(user: current_user)
    respond_with(@chat)
  end

  private

  def set_chat
    @chat = Chat.find(params[:id])
  end
  private

  def set_chats_collection
    @chats = Chat.all
  end
end
