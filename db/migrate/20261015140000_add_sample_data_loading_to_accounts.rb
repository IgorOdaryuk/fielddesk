class AddSampleDataLoadingToAccounts < ActiveRecord::Migration[8.1]
  def change
    add_column :accounts, :sample_data_loading, :boolean, null: false, default: false
  end
end
