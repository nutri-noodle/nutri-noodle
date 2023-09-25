class CreateProfile < ActiveRecord::Migration[7.0]
  def change
    create_table :profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.references :goal, null: false, foreign_key: true
      t.date :birthdate
      t.string :gender
      t.float :weight

      t.timestamps
    end
    add_reference :goals, :profile
  end
end
