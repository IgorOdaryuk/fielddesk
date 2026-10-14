class CreateJobs < ActiveRecord::Migration[8.1]
  def up
    # Human-facing job numbers come from a Postgres sequence, so two
    # dispatchers booking at the same second never collide.
    execute "CREATE SEQUENCE job_numbers START 10001"

    create_table :jobs do |t|
      t.string :number, null: false, default: -> { "'J-' || nextval('job_numbers')" }
      t.references :customer, null: false, foreign_key: true
      t.references :property, null: false, foreign_key: true
      t.references :technician, foreign_key: { to_table: :users }
      t.references :created_by, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.integer :priority, null: false, default: 1
      t.string :appliance, null: false
      t.string :brand
      t.string :model_number
      t.text :problem, null: false
      t.string :source
      t.datetime :scheduled_at
      t.integer :duration_minutes, null: false, default: 120
      t.datetime :started_at
      t.datetime :completed_at
      t.string :cancel_reason

      t.timestamps
    end
    add_index :jobs, :number, unique: true
    add_index :jobs, :status
    add_index :jobs, :scheduled_at
  end

  def down
    drop_table :jobs
    execute "DROP SEQUENCE job_numbers"
  end
end
