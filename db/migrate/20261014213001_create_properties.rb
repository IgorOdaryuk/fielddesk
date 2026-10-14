class CreateProperties < ActiveRecord::Migration[8.1]
  def change
    create_table :properties do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :street, null: false
      t.string :unit
      t.string :city, null: false
      t.string :state, null: false, limit: 2
      t.string :zip, null: false
      t.text :access_notes

      t.timestamps
    end
  end
end
