class AddIndexUniqueConstraintToPreservedCopies < ActiveRecord::Migration[5.1]
  def up
    add_index :preserved_copies, [:preserved_object_id, :endpoint_id, :version], :unique => true,
      name: 'index_preserved_copies_on_po_and_endpoint_and_version'
  end
  def down
    remove_index :preserved_copies, column: [:preserved_object_id, :endpoint_id, :version]
  end
end
