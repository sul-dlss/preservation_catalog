FactoryBot.define do
  factory :archive_preserved_copy do
    status 'unreplicated'
    archive_endpoint
    preserved_copy
  end
end
