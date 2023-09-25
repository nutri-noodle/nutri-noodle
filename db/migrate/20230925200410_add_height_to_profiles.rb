class AddHeightToProfiles < ActiveRecord::Migration[7.0]
  def change
    add_column :profiles, :height, :float
  end
end
