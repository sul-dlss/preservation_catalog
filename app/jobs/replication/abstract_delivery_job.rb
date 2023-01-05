# frozen_string_literal: true

module Replication
  # Invokes `ZipDeliveryService`
  # Notify `Replication::ResultsRecorderJob`, if posted.
  class AbstractDeliveryJob < Replication::ZipPartJobBase
    before_enqueue { |job| job.zip_info_check!(job.arguments.fourth) }

    # @param [String] druid
    # @param [Integer] version
    # @param [String] part_s3_key
    # @param [Hash<Symbol => String, Integer>] metadata Zip info
    # @see Replication::DeliveryDispatcherJob#perform warning about why metadata must be passed
    def perform(druid, version, part_s3_key, metadata)
      return unless Replication::ZipDeliveryService.deliver(
        s3_part: bucket.object(part_s3_key),
        dvz_part: dvz_part, # defined in this class's parent: `Replication::ZipPartJobBase`
        metadata: metadata
      )

      Replication::ResultsRecorderJob.perform_later(druid, version, part_s3_key, self.class.to_s)
    end

    def bucket
      raise NotImplementedError, 'Child of abstract delivery job failed to override `#bucket` method'
    end
  end
end
