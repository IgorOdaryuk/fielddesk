class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false
      t.string :name, null: false
      t.string :phone
      t.integer :role, null: false, default: 2
      t.boolean :active, null: false, default: true
      t.string :color, null: false, default: "#2563eb"
      t.datetime :last_sign_in_at

      t.timestamps
    end
    add_index :users, :email_address, unique: true
    add_index :users, :role
  end
end
