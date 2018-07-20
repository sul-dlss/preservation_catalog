FactoryBot.define do
  # Because ZMVs are auto-created in callback, you probably don't create from this factory directly.
  # Instead create a :preserved_copy and get the zipped_moab_versions from it
  factory :zipped_moab_version do
    status 'unreplicated'
    version 1
    zip_endpoint
    preserved_copy
  end
end
