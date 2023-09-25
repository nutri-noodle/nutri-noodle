class ProfileDietaryPreference < ApplicationRecord
  belongs_to :profile
  belongs_to :dietary_preference, class_name: 'Tag'
end
