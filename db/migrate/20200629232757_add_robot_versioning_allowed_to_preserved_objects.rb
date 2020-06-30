class AddRobotVersioningAllowedToPreservedObjects < ActiveRecord::Migration[6.0]
  # NOTE: this disables the wrapping transaction for the entire migration.
  # Requested in code review:
  # https://github.com/sul-dlss/preservation_catalog/pull/1608#pullrequestreview-441068958
  disable_ddl_transaction!

  def change
    add_column :preserved_objects, :robot_versioning_allowed, :boolean, null: false, default: true
  end
end
