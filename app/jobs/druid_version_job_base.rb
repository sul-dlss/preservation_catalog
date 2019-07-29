# frozen_string_literal: true

# A common base for jobs based around druid and version (with locking).
# Prepopulates the `zip` with a DruidVersionZip object
class DruidVersionJobBase < ApplicationJob
  attr_accessor :zip

  before_perform do |job|
    job.zip = DruidVersionZip.new(job.arguments.first, job.arguments.second)
  end

  # Does queue locking on ONLY druid and version (as first and second parameters)
  def lock(*args)
    "lock:#{name}-#{args.slice(0..1)}"
  end

  # A Job subclass must implement this method:
  # @param [String] druid
  # @param [Integer] version
  # ...
  # def perform(druid, version, ...)
end
