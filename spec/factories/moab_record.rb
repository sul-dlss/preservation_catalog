# frozen_string_literal: true

FactoryBot.define do
  factory :moab_record do
    version { 1 }
    status { 'ok' }
    size { 231 }
    moab_storage_root
    preserved_object
  end
end
