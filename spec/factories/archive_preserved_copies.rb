FactoryBot.define do
  factory :archive_preserved_copy do
    status 'unreplicated'
    version 1
    archive_endpoint
    preserved_copy
    version 1
  end
end
