# frozen_string_literal: true

module Replication
  # Precondition(s):
  #  All needed PreservedObject and ZippedMoabVersion database rows are already made.
  # @see PreservedObject#create_zipped_moab_versions!
  #
  # Responsibilities:
  # Record zip part metadata info in DB.
  # Split message out to all necessary zip endpoints.
  # For example:
  #   Endpoint1Delivery.perform_later(druid, version, part_s3_key, zip_metadata)
  #   Endpoint2Delivery.perform_later(druid, version, part_s3_key, zip_metadata)
  #   ...
  #
  # Note: We can't get zip metadata from (the DruidVersionZip), as zip metadata
  #   is specific to the VM and the time it was run (e.g. if the zip utility on
  #   the VM is updated to a new vesrion). Therefore, we receive the zip
  #   metadata from the process that actually created the zip file.
  class DeliveryDispatcherJob < Replication::ZipPartJobBase
    queue_as :replication_delivery_dispatcher

    before_enqueue do |job|
      job.zip_info_check!(job.arguments.fourth)
    end

    # @param [String] druid
    # @param [Integer] version
    # @param [String] part_s3_key, e.g. 'ab/123/cd/4567/ab123cd4567.v0001.z03'
    # @param [Hash<Symbol => String>] metadata about the creation of the ZipPart
    # @option metadata [Integer] :parts_count
    # @option metadata [Integer] :size
    # @option metadata [String] :checksum_md5
    # @option metadata [String] :suffix
    # @option metadata [String] :zip_cmd
    # @option metadata [String] :zip_version
    def perform(druid, version, part_s3_key, metadata)
      zipped_moab_versions.each do |zmv|
        find_or_create_unreplicated_part(zmv, part_s3_key, metadata)
      end
      deliverers.each { |worker| worker.perform_later(druid, version, part_s3_key, metadata) }
    end

    private

    # @return [ActiveRecord::Relation] effectively an Array of ZippedMoabVersion objects
    def zipped_moab_versions
      @zipped_moab_versions ||= ZippedMoabVersion.by_druid(zip.druid.id).where(version: zip.version)
    end

    def find_or_create_unreplicated_part(zipped_moab_version, part_s3_key, metadata)
      zipped_moab_version.zip_parts.create_with(
        create_info: metadata.slice(:zip_cmd, :zip_version).to_s,
        md5: metadata[:checksum_md5],
        parts_count: metadata[:parts_count],
        size: metadata[:size],
        suffix: File.extname(part_s3_key)
      ).create_or_find_by(suffix: File.extname(part_s3_key), &:unreplicated!)
    end

    # @return [Array<Class>] endpoint specific delivery classes
    def deliverers
      zipped_moab_versions
        .filter { |zmv| !zmv.all_parts_replicated? }
        .map { |zmv| zmv.zip_endpoint.delivery_class.constantize }.uniq
    end
  end
end
