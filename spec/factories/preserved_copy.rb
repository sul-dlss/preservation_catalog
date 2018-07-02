FactoryBot.define do
  factory :preserved_copy do
    version 1
    status 'ok'
    size 231
    endpoint
    preserved_object
  end

  factory :archive_copy_deprecated, parent: :preserved_copy do
    association :endpoint, factory: :archive_endpoint_deprecated
  end

  factory :unreplicated_copy_deprecated, parent: :archive_copy_deprecated do
    status 'unreplicated'
  end
end
