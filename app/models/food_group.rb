class FoodGroup < ApplicationRecord
  validates_presence_of :name
  auto_strip_attributes :name
  def self.api_query(params)
    params = params.to_unsafe_h if params.respond_to?(:to_unsafe_h)
    filtered_records = all
    filtered_records=filtered_records.where("name ilike ?", "#{params[:search].parameterize}%") if params[:search].present?
    filtered_records
  end
end
