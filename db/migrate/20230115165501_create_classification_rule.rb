class CreateClassificationRule < ActiveRecord::Migration[7.0]
  def change
    create_table :classification_rules do |t|
      t.string :rule

      t.timestamps
    end
  end
end
