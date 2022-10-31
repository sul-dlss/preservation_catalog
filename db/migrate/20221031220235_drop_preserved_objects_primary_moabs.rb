class DropPreservedObjectsPrimaryMoabs < ActiveRecord::Migration[7.0]
  def change
    drop_table :preserved_objects_primary_moabs
  end
end
