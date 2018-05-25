class RemoveRecoveryCostFromEndpoints < ActiveRecord::Migration[5.1]
  def change
    remove_column :endpoints, :recovery_cost, :integer
  end
end
