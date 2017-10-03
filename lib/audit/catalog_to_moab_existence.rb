require 'druid-tools'

# Catalog to Moab existence check code
class CatalogToMoabExistence

  # NOTE: this is a bad thing -- HUGE list of objects;  just for now to populate test db
  # FIXME:  temporarily turning off rubocop
  # rubocop:disable all
  def self.whole_db
    PreservationCopy.all.each do |pc|
      id = pc.preserved_object.druid
      version = pc.current_version
      storage_location = pc.endpoint.storage_location
      druid = DruidTools::Druid.new(id)
      object_dir = "#{storage_location}/#{druid.tree.join('/')}"

      moab = Moab::StorageObject.new(id, object_dir)
      moab_version = moab.current_version_id
      if version == moab_version
        p "hurray - #{id} versions match: #{version}"
      else
        p "boo - #{id} catalog has #{version} but moab has #{moab_version}"
      end

      # TODO: update status, timestamps, report errors, log, etc.
    end
  end
  # rubocop:enable all

end
