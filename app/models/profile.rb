class Profile < ApplicationRecord
  has_one :goal, dependent: :destroy
  has_many :profile_medical_conditions, dependent: :destroy
  validates :name, presence: true
end
