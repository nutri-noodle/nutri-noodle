class Profile < ApplicationRecord
  include ActionView::RecordIdentifier

  has_one :goal, dependent: :destroy
  has_many :profile_medical_conditions, dependent: :destroy
  has_many :medical_conditions, through: :profile_medical_conditions
  has_many :profile_allergens, dependent: :destroy
  has_many :allergens, through: :profile_allergens
  has_many :profile_dietary_preferences, dependent: :destroy
  has_many :dietary_preferences, through: :profile_dietary_preferences
  validates :birthdate, :gender, presence: true

  accepts_nested_attributes_for :medical_conditions, :allergens, :dietary_preferences

  broadcasts_to(->(profile) { profile.user.dom_id(profile.user, :profile) },
                target: ->(profile) { profile.user.dom_id(profile.user, :profile) })

end
