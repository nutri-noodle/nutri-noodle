class ShoppingListController < ApplicationController
  layout false
  skip_before_action :authenticate_user!
  def show
    user = User.find(params[:user_id])
    @messages = user.messages.where(role: :assistant)
  end
end
