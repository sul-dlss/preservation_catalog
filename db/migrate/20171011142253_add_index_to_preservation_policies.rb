class AddIndexToPreservationPolicies < ActiveRecord::Migration[5.1]
  def change
    add_index :preservation_policies, :preservation_policy_name, unique: true
  end
end
