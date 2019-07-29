# frozen_string_literal: true

FactoryBot.define do
  factory :complete_moab do
    version { 1 }
    status { 'ok' }
    size { 231 }
    moab_storage_root
    preserved_object
  end
end
