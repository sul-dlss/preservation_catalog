FactoryBot.define do
  factory :endpoint_type do
    sequence(:type_name) { |n| endpoint_class + format('%02d', n) }
    endpoint_class 'online'
  end
end
