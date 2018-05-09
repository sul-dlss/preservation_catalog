# A common base for Endpoint delivery jobs in a Rails context.
# Prepopulates the `zip` with a DruidVersionZip object
class EndpointDeliveryBase < ApplicationJob
  attr_accessor :zip

  before_perform do |job|
    job.zip = DruidVersionZip.new(job.arguments.first, job.arguments.second)
  end

  # In Job subclass, implement this method:
  # @param [String] druid
  # @param [Integer] version
  # def perform(druid, version)
end
