class RenameArchiveEndpointToZipEndpoint < ActiveRecord::Migration[5.1]
  def change
    # removed index and added index back, to keep the index names consistent with the updated table names.
    remove_index :archive_endpoints_preservation_policies, name: "index_archive_endpoints_pres_policies_on_pres_policy_id"
    remove_index :archive_endpoints_preservation_policies, name: "index_archive_endpoints_pres_policies_on_archive_endpoint_id"
    rename_table :archive_endpoints, :zip_endpoints
    rename_column :archive_preserved_copies, :archive_endpoint_id, :zip_endpoint_id
    rename_table :archive_endpoints_preservation_policies, :preservation_policies_zip_endpoints
    rename_column :preservation_policies_zip_endpoints, :archive_endpoint_id, :zip_endpoint_id
    add_index :preservation_policies_zip_endpoints, :zip_endpoint_id, name: "index_pres_policies_zip_endpoints_on_zip_endpoint_id"
    add_index :preservation_policies_zip_endpoints, :preservation_policy_id, name: "index_pres_policies_zip_endpoints_on_pres_policy_id"
  end
end
