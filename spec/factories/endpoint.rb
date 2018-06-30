FactoryBot.define do
  factory :endpoint, aliases: [:online_endpoint] do
    sequence(:endpoint_name) { |n| "endpoint#{format('%02d', n)}" }
    endpoint_node 'localhost'
    storage_location { "spec/fixtures/#{endpoint_name}/sdr2objects" }
    endpoint_type # default online
  end

  factory :archive_endpoint_deprecated, parent: :endpoint do
    delivery_class 1
    association :endpoint_type, endpoint_class: 'archive'
  end
end
