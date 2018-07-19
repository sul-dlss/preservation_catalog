class RenameEndpointToMoabStorageRoot < ActiveRecord::Migration[5.1]
  def change
    remove_index :endpoints, :endpoint_node
    remove_column :endpoints, :endpoint_node, :string
    rename_column :endpoints, :endpoint_name, :name
    rename_table :endpoints, :moab_storage_roots

    # we remove and then add indexes as we get this error if we use default index names:
    #   "Index name xx on table yy is too long; the limit is 63 characters" <- for postgres

    remove_index :preserved_copies, name: 'index_preserved_copies_on_po_and_endpoint_and_version'
    rename_column :preserved_copies, :endpoint_id, :moab_storage_root_id
    add_index :preserved_copies, [:preserved_object_id, :moab_storage_root_id, :version],
      unique: true,
      name: 'index_preserved_copies_on_po_and_storage_root_and_version'

    remove_index :endpoints_preservation_policies, :preservation_policy_id
    remove_index :endpoints_preservation_policies, :endpoint_id
    rename_table :endpoints_preservation_policies, :moab_storage_roots_preservation_policies
    rename_column :moab_storage_roots_preservation_policies, :endpoint_id, :moab_storage_root_id
    # note abbreviations in index names to keep name shorter than 63 characters
    add_index :moab_storage_roots_preservation_policies, :preservation_policy_id, name: 'index_moab_storage_roots_pres_policies_on_pres_policy_id'
    add_index :moab_storage_roots_preservation_policies, :moab_storage_root_id, name: 'index_moab_storage_roots_pres_policies_on_moab_storage_root_id'
  end
end
