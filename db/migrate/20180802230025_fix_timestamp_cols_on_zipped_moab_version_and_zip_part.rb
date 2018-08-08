class FixTimestampColsOnZippedMoabVersionAndZipPart < ActiveRecord::Migration[5.1]
  def change
    # drop last_existence_check from ZMV, add that and last_checksum_validation to ZipPart
    remove_column :zipped_moab_versions, :last_existence_check, :datetime
    add_column :zip_parts, :last_existence_check, :datetime
    add_column :zip_parts, :last_checksum_validation, :datetime
  end
end
