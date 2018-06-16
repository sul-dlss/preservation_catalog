# Confirm checksum for one (online) PreservedCopy, updating database
# @see ChecksumValidator
class ChecksumValidationJob < ApplicationJob
  queue_as :checksum_validation

  before_enqueue do |job|
    raise ArgumentError, 'PreservedCopy param required' unless job.arguments.first.is_a?(PreservedCopy)
  end

  # @param [PreservedCopy] preserved_copy object to checksum
  def perform(preserved_copy)
    ChecksumValidator.new(preserved_copy).validate_checksums
  end
end
