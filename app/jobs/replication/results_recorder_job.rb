# frozen_string_literal: true

module Replication
  # Preconditions: ZipPart exists in database
  #
  # Responsibilities:
  # 1. Update ZipPart status in database.
  # 2. when all zip parts for the druid version are delivered to ONE endpoint,
  #   Report to DOR event service
  class ResultsRecorderJob < ApplicationJob
    queue_as :zip_endpoint_events

    include UniqueJob

    # @param [String] druid
    # @param [Integer] version
    # @param [String] s3_part_key
    # @param [String] delivery_class Name of the worker class that performed delivery
    def perform(druid, version, s3_part_key, delivery_class)
      zipped_moab_version = find_zipped_moab_version(druid, version, delivery_class)
      zip_part_ok!(zipped_moab_version, s3_part_key)

      # log to event service if all ZipParts are replicated for this endpoint
      create_zmv_replicated_event(druid, zipped_moab_version) if zipped_moab_version.reload.all_parts_replicated?
    end

    private

    def find_zipped_moab_version(druid, version, delivery_class)
      ZippedMoabVersion.by_druid(druid)
                       .joins(:zip_endpoint)
                       .find_by!(zip_endpoints: { delivery_class: delivery_class }, version: version)
    end

    def zip_part_ok!(zipped_moab_version, s3_part_key)
      zipped_moab_version.zip_parts.find_by!(
        suffix: File.extname(s3_part_key),
        status: 'unreplicated'
      ).ok!
    end

    def create_zmv_replicated_event(druid, zipped_moab_version)
      parts_info = zipped_moab_version.zip_parts.order(:suffix).map do |part|
        { s3_key: part.s3_key, size: part.size, md5: part.md5 }
      end

      Dor::Event::Client.create(
        druid: "druid:#{druid}",
        type: 'druid_version_replicated',
        data: {
          host: Socket.gethostname,
          invoked_by: 'preservation-catalog',
          version: zipped_moab_version.version,
          endpoint_name: zipped_moab_version.zip_endpoint.endpoint_name,
          parts_info: parts_info
        }
      )
    end
  end
end
