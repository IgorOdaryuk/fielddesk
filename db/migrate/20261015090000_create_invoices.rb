class CreateInvoices < ActiveRecord::Migration[8.1]
  def up
    execute "CREATE SEQUENCE invoice_numbers START 5001"

    create_table :invoices do |t|
      t.string :number, null: false, default: -> { "'INV-' || nextval('invoice_numbers')" }
      t.references :job, null: false, foreign_key: true, index: { unique: true }
      t.integer :status, null: false, default: 0
      t.integer :tax_rate_bps, null: false, default: 0
      t.integer :subtotal_cents, null: false, default: 0
      t.integer :tax_cents, null: false, default: 0
      t.integer :total_cents, null: false, default: 0
      t.integer :paid_cents, null: false, default: 0
      t.string :payment_token, null: false
      t.date :due_on
      t.datetime :sent_at
      t.datetime :paid_at
      t.datetime :voided_at
      t.text :notes

      t.timestamps
    end
    add_index :invoices, :number, unique: true
    add_index :invoices, :payment_token, unique: true
    add_index :invoices, :status
  end

  def down
    drop_table :invoices
    execute "DROP SEQUENCE invoice_numbers"
  end
end
