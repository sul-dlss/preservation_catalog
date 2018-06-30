FactoryBot.define do
  factory :archive_endpoint do
    sequence(:endpoint_name) { |n| "endpoint#{format('%02d', n)}" }
    delivery_class 1
    preservation_policies { [PreservationPolicy.default_policy] }
  end
end
