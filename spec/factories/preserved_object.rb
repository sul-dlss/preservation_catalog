FactoryBot.define do
  factory :preserved_object do
    sequence(:druid) { |n| 'bj102hs' + format('%04d', 9686 + n) } # start at bj102hs9687
    current_version 1
    preservation_policy { PreservationPolicy.default_policy }
  end
end
