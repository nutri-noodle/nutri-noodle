module FoodGroupQueryHelper
  extend ActiveSupport::Concern

  def process_food_groups
    @filtered_food_groups = FoodGroup.api_query(filtered_food_group_params)
    @count = @filtered_food_groups.count
    @food_groups = @filtered_food_groups.offset(offset).limit(page_length).order(:name => :asc)
    @show_next = more_pages_count < @count
    @page = page
  end

  private
  def filtered_food_group_params
    if params.has_key?(:filtered_admin_food_group)
      params[:filtered_admin_food_group].permit!
    else
      params
    end
  end
end
