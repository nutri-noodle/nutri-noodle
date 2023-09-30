# app/controllers/shoes_controller.rb
class FoodHoverController < ApplicationController

  def show
    @food = Food.find(params[:id])

    render layout: false
  end
end
