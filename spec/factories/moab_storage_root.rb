FactoryBot.define do
  factory :moab_storage_root, aliases: [:online_endpoint] do
    sequence(:name) { |n| "moab_storage_root#{format('%02d', n)}" }
    storage_location { "spec/fixtures/#{name}/sdr2objects" }
  end
end
