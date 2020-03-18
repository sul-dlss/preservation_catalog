# frozen_string_literal: true

# Migrates Complete Moab records to a new Moab Storate Root.
class StorageRootMigrationService
  def initialize(from_name, to_name)
    @from_name = from_name
    @to_name = to_name
  end

  # @return [Array<String>] druids of migrated moabs
  def migrate
    druids = []
    from_root.complete_moabs.find_each do |complete_moab|
      complete_moab.migrate_moab(to_root).save!
      druids << complete_moab.preserved_object.druid
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
