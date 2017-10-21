require 'druid-tools'

# Catalog to Moab existence check code
class CatalogToMoab

  # NOTE: this is at the chicken scratches stage
  #  I'm not convinced we'll _ever_ do the whole db this way;  it was a way to start
  #    step 1: ensure load_fixtures_helper works with very rough code here
  # FIXME:  temporarily turning off rubocop
  # rubocop:disable all
  def self.check_existence
    PreservationCopy.find_each do |pc|
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
