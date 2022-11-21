# frozen_string_literal: true

module MoabOnStorage
  ##
  # Utility methods for Moab::StorageObject and Druid
  class MoabUtils
    # @param druid [String]
    # @param storage_location [String] the root directory holding the druid tree (the storage root path)
    def self.object_dir(druid:, storage_location:)
      DruidTools::Druid.new(druid, storage_location).path
    end

    # @param druid [String]
    # @param storage_location [String] the root directory holding the druid tree (the storage root path)
    def self.moab(druid:, storage_location:)
      Moab::StorageObject.new(druid, object_dir(druid: druid, storage_location: storage_location))
    end
  end
end