class CreateInvoiceItems < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.integer :kind, null: false, default: 0
      t.string :description, null: false
      t.decimal :quantity, precision: 8, scale: 2, null: false, default: 1
      t.integer :unit_price_cents, null: false
      t.boolean :taxable, null: false, default: false

      t.timestamps
    end
  end
end
