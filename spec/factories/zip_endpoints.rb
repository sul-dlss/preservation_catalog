# frozen_string_literal: true

FactoryBot.define do
  factory :zip_endpoint do
    sequence(:endpoint_name) { |n| "endpoint#{format('%02d', n)}" }
    sequence(:endpoint_node) { |n| "us-west-#{format('%02d', n)}" }
    storage_location { 'bucket_name' }
  end
end
