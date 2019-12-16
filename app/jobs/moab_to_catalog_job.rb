# frozen_string_literal: true

# Check catalog based on filesystem, updating database
# @see PreservedObjectHandler#check_existence
class MoabToCatalogJob < ApplicationJob
  queue_as :m2c

  before_enqueue do |job|
    raise ArgumentError, 'MoabStorageRoot param required' unless job.arguments.first.is_a?(MoabStorageRoot)
  end

  # @param [MoabStorageRoot] root mount containing the Moab
  # @param [String] druid
  # @param [String] optional path
  def perform(root, druid, path=nil)
    path = "#{root.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}" if path.nil?
    moab = Moab::StorageObject.new(druid, path)
    PreservedObjectHandler.new(druid, moab.current_version_id, moab.size, root).check_existence
  end
end
