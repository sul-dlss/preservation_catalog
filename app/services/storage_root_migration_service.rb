# frozen_string_literal: true

# Migrates MoabRecord records to a new Moab Storate Root.
class StorageRootMigrationService
  def initialize(from_name, to_name)
    @from_name = from_name
    @to_name = to_name
  end

  # @return [Array<String>] druids of migrated moabs
  def migrate
    druids = []
    from_root.moab_records.find_each do |moab_record|
      moab_record.migrate_moab(to_root).save!
      druids << moab_record.preserved_object.druid
    end
    druids
  end

  private

  def from_root
    @from_root ||= MoabStorageRoot.find_by!(name: @from_name)
  end

  def to_root
    @to_root ||= MoabStorageRoot.find_by!(name: @to_name)
  end
end
