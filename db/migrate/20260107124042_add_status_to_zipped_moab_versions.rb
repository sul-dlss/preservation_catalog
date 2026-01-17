class AddStatusToZippedMoabVersions < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_column :zipped_moab_versions, :status, :integer, default: 2, null: false
    add_column :zipped_moab_versions, :status_updated_at, :datetime, precision: nil
    add_column :zipped_moab_versions, :zip_parts_count, :integer

    add_index :zipped_moab_versions, :status
    add_index :zipped_moab_versions, :status_updated_at

    # Set status to 'ok'. Auditing will set this correctly later.
    ZippedMoabVersion.update_all(status: 0)

    # NOTE: We went back and modified this for the historical record, as we didn't run this last step
    # for the prod migration.  It hit a PostgreSQL connection timeout after a couple hours of running.
    # We did this out-of-band from cap deployment migration by running the new replication audit job on
    # these same objects in a rails console session in screen.
    #
    # For ZippedMoabVersions without any ZipParts, set status to 'created'.
    # ZippedMoabVersion.where.missing(:zip_parts).update_all(status: 2, status_updated_at: Time.current)
  end
end
