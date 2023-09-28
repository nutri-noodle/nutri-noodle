class ProfileMedicalCondition < ApplicationRecord
  belongs_to :profile
  belongs_to :medical_condition
end
