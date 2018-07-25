require 'rails_helper'

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
  before do
    setup
    load_fixture_moabs # automatically undone by rails transactional test scope
  end
end

def load_fixture_moabs
  @moab_storage_dirs.each do |storage_dir|
    Stanford::MoabStorageDirectory.find_moab_paths(storage_dir) do |druid, _path, _path_match_data|
      version = Stanford::StorageServices.current_version(druid)
      size = Stanford::StorageServices.object_size(druid)
      po = PreservedObject.create(druid: druid,
                                  current_version: version,
                                  preservation_policy: PreservationPolicy.default_policy)
      PreservedCopy.create(preserved_object_id: po.id,
                           moab_storage_root_id: @storage_dir_to_moab_storage_root_id[storage_dir],
                           version: version,
                           size: size,
                           status: 'validity_unknown')
    end
  end
end

def setup
  @moab_storage_dirs = []
  @storage_dir_to_moab_storage_root_id = {}
  HostSettings.storage_roots.to_h.each_value do |storage_root|
    storage_dir = File.join(storage_root, Settings.moab.storage_trunk)
    @moab_storage_dirs << storage_dir
    @storage_dir_to_moab_storage_root_id[storage_dir] = MoabStorageRoot.find_by(storage_location: storage_dir).id
  end
end
