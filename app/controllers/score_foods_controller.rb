class ScoreFoodsController < ApplicationController
  def index
    prepend_view_path "recipes"
  end
end
