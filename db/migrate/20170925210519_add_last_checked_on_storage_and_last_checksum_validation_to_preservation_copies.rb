class AddLastCheckedOnStorageAndLastChecksumValidationToPreservationCopies < ActiveRecord::Migration[5.1]
  def change
    add_column :preservation_copies, :last_checked_on_storage, :datetime
    add_column :preservation_copies, :last_checksum_validation, :datetime
  end
end
