class CreateMedicalConditions < ActiveRecord::Migration[7.0]
  def change
    create_table :medical_conditions do |t|
      t.string :name
      t.integer :display_order

      t.timestamps
    end
  end
end
