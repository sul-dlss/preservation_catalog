# frozen_string_literal: true

# Confirm checksum for one (online) CompleteMoab, updating database
# @see Audit::ChecksumValidator
class ChecksumValidationJob < ApplicationJob
  queue_as :checksum_validation

  before_enqueue do |job|
    raise ArgumentError, 'CompleteMoab param required' unless job.arguments.first.is_a?(CompleteMoab)
  end

  include UniqueJob

  # @param [CompleteMoab] complete_moab object to checksum
  def perform(complete_moab)
    Audit::ChecksumValidator.new(complete_moab).validate_checksums
  end
end
