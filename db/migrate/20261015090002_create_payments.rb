class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :recorded_by, foreign_key: { to_table: :users }
      t.integer :amount_cents, null: false
      t.integer :method, null: false
      t.string :reference
      t.string :gateway
      t.string :gateway_id
      t.datetime :received_at, null: false

      t.timestamps
    end
    add_index :payments, [ :gateway, :gateway_id ], unique: true, where: "gateway_id IS NOT NULL"
  end
end
