# frozen_string_literal: true

# Check catalog based on filesystem, updating database
# @see MoabRecordService::CheckExistence
class MoabToCatalogJob < ApplicationJob
  queue_as :m2c

  before_enqueue do |job|
    raise ArgumentError, 'MoabStorageRoot param required' unless job.arguments.first.is_a?(MoabStorageRoot)
  end

  include UniqueJob

  # @param [MoabStorageRoot] root mount containing the Moab
  # @param [String] druid
  def perform(root, druid)
    path = DruidTools::Druid.new(druid, root.storage_location).path.to_s
    moab = Moab::StorageObject.new(druid, path)
    MoabRecordService::CheckExistence.execute(druid: druid, incoming_version: moab.current_version_id, incoming_size: moab.size,
                                              moab_storage_root: root)
  end
end
