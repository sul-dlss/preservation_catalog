FactoryBot.define do
  factory :zipped_moab_version do
    status 'unreplicated'
    version 1
    archive_endpoint
    preserved_copy
  end
end
