class RemovePreservationPolicyFromPreservedObjects < ActiveRecord::Migration[5.1]
  def change
    remove_column :preserved_objects, :preservation_policy, :string
  end
end
