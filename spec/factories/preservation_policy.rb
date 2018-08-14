FactoryBot.define do
  factory :preservation_policy do
    preservation_policy_name 'default'
    archive_ttl 7_776_000
    fixity_ttl 7_776_000
  end
end
