FactoryBot.define do
  factory :preserved_copy do
    version 1
    status 'ok'
    size 231
    endpoint
    preserved_object
  end

  factory :archive_copy, parent: :preserved_copy do
    association :endpoint, factory: :archive_endpoint
  end

  factory :unreplicated_copy, parent: :archive_copy do
    status 'unreplicated'
  end
end
