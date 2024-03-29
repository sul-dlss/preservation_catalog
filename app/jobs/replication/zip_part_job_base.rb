# frozen_string_literal: true

module Replication
  # A common base for jobs based around druid and version (with locking).
  # Prepopulates the `zip` with a DruidVersionZip object
  class ZipPartJobBase < ApplicationJob
    attr_accessor :dvz_part, :zip

    before_perform do |job|
      job.zip = Replication::DruidVersionZip.new(job.arguments.first, job.arguments.second)
      job.dvz_part = Replication::DruidVersionZipPart.new(zip, job.arguments.third)
    end

    include UniqueJob

    # Does queue locking on ONLY druid, version and part (as first 3 parameters)
    def self.queue_lock_key(*args)
      "lock:#{name}-#{args.slice(0..2).join(';')}"
    end

    # A Job subclass must implement this method:
    # @param [String] druid
    # @param [Integer] version
    # @param [String] s3_part_key
    # ...
    # def perform(druid, version, s3_part_key, ...)
  end
end
