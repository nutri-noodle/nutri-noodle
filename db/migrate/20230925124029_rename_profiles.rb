class RenameProfiles < ActiveRecord::Migration[7.0]
  def change
    rename_table :profiles, :profile_groups
    rename_column :goals, :profile_id, :profile_group_id
    rename_table :profile_medical_conditions, :profile_group_medical_conditions
  end
end
