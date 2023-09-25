class ProfileAllergen < ApplicationRecord
  belongs_to :profile
  belongs_to :allergens, class_name: 'Tag'
end
