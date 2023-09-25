class HomeController < ApplicationController
  def index
    if(current_user.profile.present?)
      redirect_to messages_path
    else
      redirect_to new_profile_path
    end
  end
end
