class CreateAccounts < ActiveRecord::Migration[8.1]
  TENANT_TABLES = %i[users customers properties jobs invoices payments outbound_messages audit_logs].freeze

  def up
    create_table :accounts do |t|
      t.string :name, null: false
      t.string :slug, null: false
      t.string :phone
      t.string :email
      t.string :address
      t.integer :tax_rate_bps, null: false, default: 0
      t.integer :payment_terms_days, null: false, default: 7
      t.string :review_url
      t.boolean :booking_enabled, null: false, default: true
      t.boolean :sandbox, null: false, default: false

      t.timestamps
    end
    add_index :accounts, :slug, unique: true

    TENANT_TABLES.each { |table| add_reference table, :account, foreign_key: true }

    # Existing single-company data moves into one account.
    if select_value("SELECT COUNT(*) FROM users").to_i.positive?
      settings = Rails.application.config_for(:company)
      account_id = select_value(<<~SQL)
        INSERT INTO accounts (name, slug, phone, email, address, tax_rate_bps, payment_terms_days, review_url, created_at, updated_at)
        VALUES (#{quote(settings[:name])}, #{quote(settings[:name].parameterize)}, #{quote(settings[:phone])}, #{quote(settings[:email])},
                #{quote(settings[:address])}, #{settings[:tax_rate_bps].to_i}, #{settings[:payment_terms_days].to_i}, #{quote(settings[:review_url])}, NOW(), NOW())
        RETURNING id
      SQL
      TENANT_TABLES.each { |table| execute "UPDATE #{table} SET account_id = #{account_id}" }
    end

    # Failed sign-ins for unknown emails belong to no company.
    (TENANT_TABLES - %i[audit_logs]).each { |table| change_column_null table, :account_id, false }
  end

  def down
    TENANT_TABLES.each { |table| remove_reference table, :account, foreign_key: true }
    drop_table :accounts
  end
end
