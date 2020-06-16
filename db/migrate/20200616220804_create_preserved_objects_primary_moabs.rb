class CreatePreservedObjectsPrimaryMoabs < ActiveRecord::Migration[6.0]
  def change
    create_table :preserved_objects_primary_moabs do |t|
      t.references :preserved_object, foreign_key: true, null: false, index: { unique: true }
      t.references :complete_moab, foreign_key: true, null: false, index: { unique: true }
      t.timestamps
    end
  end
end
