class DropRobotVersioningAllowed < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    remove_column :preserved_objects, :robot_versioning_allowed, :boolean, default: true, null: false
  end
end
