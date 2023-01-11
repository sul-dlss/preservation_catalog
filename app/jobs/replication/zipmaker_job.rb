# frozen_string_literal: true

module Replication
  # Responsibilities:
  # For a given version of a druid:
  #   1. Ensure checksummed zip files (created from binaries from Moab on storage) are in zip cache
  #        Note: a single DruidVersionZip may have more than one ZipPart.
  #   2. Invoke Replication::DeliveryDispatcherJob for each ZipPart.
  class ZipmakerJob < ApplicationJob
    queue_as :zipmaker
    delegate :find_or_create_zip!, :file_path, :part_keys, to: :zip

    attr_accessor :zip

    before_perform do |job|
      job.zip = Replication::DruidVersionZip.new(job.arguments.first, job.arguments.second, job.arguments.third)
    end

    # esp useful safeguard here, since we can't transactionally look for an existing zip file and create
    # a new one if one isn't found.
    include UniqueJob

    # Does queue locking on ONLY druid and version (as first and second parameters)
    def self.queue_lock_key(*args)
      "lock:#{name}-#{args.slice(0..1).join(';')}"
    end

    # @param [String] druid
    # @param [Integer] version
    # @param [String] moab_replication_path The path containing the druid tree from which the zipped version should be
    #   created.  used via job.arguments in before_perform setup.
    def perform(druid, version, moab_replication_path) # rubocop:disable Lint/UnusedMethodArgument
      wait_as_needed

      find_or_create_zip!
      part_keys.each do |part_key|
        Replication::DeliveryDispatcherJob.perform_later(druid, version, part_key, Replication::DruidVersionZipPart.new(zip, part_key).metadata)
      end
    end
  end
end
