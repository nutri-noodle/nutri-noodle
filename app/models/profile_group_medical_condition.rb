class ProfileGroupMedicalCondition < ApplicationRecord
  belongs_to :profile_group
  belongs_to :medical_condition
end
