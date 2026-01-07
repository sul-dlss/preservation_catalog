class AddStatusToZippedMoabVersions < ActiveRecord::Migration[8.0]
  def change
    add_column :zipped_moab_versions, :status, :integer, default: 2, null: false
    add_column :zipped_moab_versions, :status_updated_at, :datetime, precision: nil
    add_column :zipped_moab_versions, :zip_parts_count, :integer

    add_index :zipped_moab_versions, :status
    add_index :zipped_moab_versions, :status_updated_at

    # Set status to 'ok'. Auditing will set this correctly later.
    ZippedMoabVersion.update_all(status: 0)

    # For ZippedMoabVersions without any ZipParts, set status to 'created'.
    ZippedMoabVersion.where.missing(:zip_parts).update_all(status: 2, status_updated_at: Time.current)
  end
end
