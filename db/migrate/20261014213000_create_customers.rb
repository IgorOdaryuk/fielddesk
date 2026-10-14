class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.string :name, null: false
      t.string :phone
      t.string :email
      t.string :source
      t.text :notes

      t.timestamps
    end
    add_index :customers, :phone
    add_index :customers, :email
    add_index :customers, :name
  end
end
