FactoryBot.define do
  factory :complete_moab do
    version 1
    status 'ok'
    size 231
    moab_storage_root
    preserved_object
  end

  factory :archive_copy_deprecated, parent: :complete_moab do
    association :moab_storage_root, factory: :archive_endpoint_deprecated
  end

  factory :unreplicated_copy_deprecated, parent: :archive_copy_deprecated do
    status 'unreplicated'
  end
end
