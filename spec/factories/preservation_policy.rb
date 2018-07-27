FactoryBot.define do
  factory :preservation_policy do
    preservation_policy_name 'default'
    archive_ttl 604_800
    fixity_ttl 604_800
  end
end
