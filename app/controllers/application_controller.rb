class ApplicationController < ActionController::Base
  before_action :authenticate_user!
  layout "navbar"
end
