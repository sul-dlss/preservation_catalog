class RemovePreservationPolicies < ActiveRecord::Migration[6.1]
  def change
    remove_foreign_key :preserved_objects, :preservation_policies
    drop_table :preservation_policies_zip_endpoints
    drop_table :moab_storage_roots_preservation_policies
    drop_table :preservation_policies
    remove_column :preserved_objects, :preservation_policy_id
  end
end
