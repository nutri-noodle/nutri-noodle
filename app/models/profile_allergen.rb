class ProfileAllergen < ApplicationRecord
  belongs_to :profile
  belongs_to :allergen, class_name: 'Tag'
end
