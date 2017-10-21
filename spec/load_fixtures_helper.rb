require 'rails_helper.rb'

RSpec.configure do |rspec|
  # This config option will be enabled by default on RSpec 4,
  # but for reasons of backwards compatibility, you have to
  # set it on RSpec 3.
  #
  # It causes the host group and examples to inherit metadata
  # from the shared context.
  rspec.shared_context_metadata_behavior = :apply_to_host_groups
end

RSpec.shared_context "fixture moabs in db" do
  before(:all) do
    setup
    load_fixture_moabs
  end
  after(:all) do
    # TODO: danger - if there are objects in the test db we want to keep
    Settings.moab.storage_roots.each_value do |storage_root|
      storage_dir = File.join(storage_root, Settings.moab.storage_trunk)
      PreservationCopy.where(endpoint_id: Endpoint.find_by(storage_location: storage_dir).id).each do |pc|
        po_id = pc.preserved_object_id
        pc.destroy
        PreservedObject.find(po_id).destroy
      end
    end
  end
end

def load_fixture_moabs
  @moab_storage_dirs.each do |storage_dir|
    MoabStorageDirectory.find_moab_paths(storage_dir) do |druid, _path, _path_match_data|
      version = Stanford::StorageServices.current_version(druid)
      size = Stanford::StorageServices.object_size(druid)
      po = PreservedObject.create(druid: druid,
                                  current_version: version,
                                  size: size,
                                  preservation_policy: PreservationPolicy.default_preservation_policy)
      PreservationCopy.create(preserved_object_id: po.id,
                              endpoint_id: @storage_dir_to_endpoint_id[storage_dir],
                              current_version: version,
                              status_id: Status.default_status.id)
    end
  end
end

def setup
  @moab_storage_dirs = []
  @storage_dir_to_endpoint_id = {}
  Settings.moab.storage_roots.each_value do |storage_root|
    storage_dir = File.join(storage_root, Settings.moab.storage_trunk)
    @moab_storage_dirs << storage_dir
    @storage_dir_to_endpoint_id[storage_dir] = Endpoint.find_by(storage_location: storage_dir).id
  end
end
