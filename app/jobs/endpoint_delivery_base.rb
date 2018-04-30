# A common base for Endpoint delivery jobs in a Rails context.
# Prepopulates the `zip` attribute.
class EndpointDeliveryBase < ApplicationJob
  attr_accessor :zip

  before_perform do |job|
    job.zip = job.class.fetch_zip(job.arguments.first, job.arguments.second)
  end

  # In Job subclass, implement this method:
  # @param [String] druid
  # @param [Integer] version
  # def perform(druid, version)

  # @return [tbd] the zipfile
  def self.fetch_zip(_druid, _version)
    # get the zip
  end
end
