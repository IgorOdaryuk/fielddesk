class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.references :user, foreign_key: { on_delete: :nullify }
      t.string :action, null: false
      t.references :auditable, polymorphic: true
      t.jsonb :audited_changes, null: false, default: {}
      t.string :ip_address
      t.string :user_agent

      t.datetime :created_at, null: false
    end
    add_index :audit_logs, :created_at
    add_index :audit_logs, :action
  end
end
