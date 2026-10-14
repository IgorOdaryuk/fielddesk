class CreateOutboundMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :outbound_messages do |t|
      t.references :customer, foreign_key: true
      t.references :job, foreign_key: true
      t.string :kind, null: false
      t.string :to, null: false
      t.text :body, null: false
      t.integer :status, null: false, default: 0
      t.string :provider
      t.string :provider_id
      t.string :error
      t.datetime :send_at, null: false
      t.datetime :sent_at

      t.timestamps
    end
    add_index :outbound_messages, :status
    add_index :outbound_messages, :created_at
  end
end
