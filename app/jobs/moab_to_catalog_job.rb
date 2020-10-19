# frozen_string_literal: true

# Check catalog based on filesystem, updating database
# @see CompleteMoabHandler#check_existence
class MoabToCatalogJob < ApplicationJob
  queue_as :m2c

  before_enqueue do |job|
    raise ArgumentError, 'MoabStorageRoot param required' unless job.arguments.first.is_a?(MoabStorageRoot)
  end

  # @param [MoabStorageRoot] root mount containing the Moab
  # @param [String] druid
  def perform(root, druid)
    path = DruidTools::Druid.new(druid, root.storage_location).path.to_s
    moab = Moab::StorageObject.new(druid, path)
    CompleteMoabHandler.new(druid, moab.current_version_id, moab.size, root).check_existence
  end
end
