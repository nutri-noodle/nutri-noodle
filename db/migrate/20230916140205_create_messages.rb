class CreateMessages < ActiveRecord::Migration[7.0]
  def change
    create_table :messages do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :role
      t.string :content

      t.timestamps
    end
  end
end
