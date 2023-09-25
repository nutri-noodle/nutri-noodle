class ProfileMedicalCondition < ApplicationRecord
  belongs_to :user
  belongs_to :medical_condition
end
