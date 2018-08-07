FactoryBot.define do
  factory :preserved_object do
    sequence(:druid) { |n| 'bj102hs' + format('%04d', 9686 + n) } # start at bj102hs9687
    current_version 1
    preservation_policy { PreservationPolicy.default_policy }
  end

  # searches through fixture dirs to find the druid, creates a complete moab for the PO
  factory :preserved_object_fixture, parent: :preserved_object do
    current_version { Stanford::StorageServices.current_version(druid) }

    after(:create) do |po|
      locations = Settings.storage_root_map['default'].to_h.values.map { |x| File.join(x, Settings.moab.storage_trunk) }
      root_dir = locations.find do |root|
        found = false
        Stanford::MoabStorageDirectory.find_moab_paths(root) do |druid, _path, _match|
          found = true if druid && druid == po.druid
        end
        found
      end
      create_list(:complete_moab, 1,
                  preserved_object: po,
                  moab_storage_root: MoabStorageRoot.find_by!(storage_location: root_dir),
                  version: po.current_version,
                  size: Stanford::StorageServices.object_size(po.druid),
                  status: 'validity_unknown')
    end
  end
end
