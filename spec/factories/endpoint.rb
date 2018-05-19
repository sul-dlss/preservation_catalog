FactoryBot.define do
  factory :endpoint, aliases: [:online_endpoint] do
    sequence(:endpoint_name) { |n| "endpoint#{format('%02d', n)}" }
    endpoint_node 'localhost'
    recovery_cost 1
    storage_location { "spec/fixtures/#{endpoint_name}/moab_storage_trunk" }
    endpoint_type # default online
  end

  factory :archive_endpoint, parent: :endpoint do
    delivery_class 1
    recovery_cost 10
    association :endpoint_type, endpoint_class: 'archive'
  end
end
