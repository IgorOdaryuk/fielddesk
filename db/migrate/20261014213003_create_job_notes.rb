class CreateJobNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :job_notes do |t|
      t.references :job, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false

      t.timestamps
    end
  end
end
