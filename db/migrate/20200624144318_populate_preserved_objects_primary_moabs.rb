class PopulatePreservedObjectsPrimaryMoabs < ActiveRecord::Migration[6.0]
  def change
    execute <<-SQL
      INSERT INTO preserved_objects_primary_moabs (preserved_object_id, complete_moab_id, created_at, updated_at)
        SELECT preserved_object_id, id, created_at, updated_at FROM complete_moabs ORDER BY created_at desc
        ON CONFLICT DO NOTHING;
    SQL
  end
end
