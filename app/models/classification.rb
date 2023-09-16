class Classification < ApplicationRecord
  enum status: [:unclassified, :possibly_classified, :classified]
  belongs_to :food
  belongs_to :food_group
  belongs_to :classication_rule, optional: true
  belongs_to :food_import, optional: true
end
