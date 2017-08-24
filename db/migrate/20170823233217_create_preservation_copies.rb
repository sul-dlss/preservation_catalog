class CreatePreservationCopies < ActiveRecord::Migration[5.1]
  def change
    create_table :preservation_copies do |t|
      t.integer :version
      t.string :status
      t.bigint :last_audited  # this is intended to store seconds after the unix epoch, for efficient date comparisons
      t.references :preserved_objects
      t.references :endpoints

      t.timestamps
    end

    add_index :preservation_copies, :preserved_objects
    add_index :preservation_copies, :endpoints
    add_index :preservation_copies, :last_audited
    change_column_null :preservation_copies, :preserved_objects_id, false
    change_column_null :preservation_copies, :endpoints_id, false
  end
end
