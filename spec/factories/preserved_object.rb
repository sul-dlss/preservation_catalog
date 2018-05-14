FactoryBot.define do
  factory :preserved_object do
    druid 'bj102hs9687'
    current_version 1
    preservation_policy { PreservationPolicy.default_policy }
  end
end
