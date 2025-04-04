# frozen_string_literal: true

module Audit
  # Confirm checksum for one Moab on storage and update MoabRecord in database
  # @see Audit::ChecksumValidationService
  class ChecksumValidationJob < ApplicationJob
    queue_as :checksum_validation

    before_enqueue do |job|
      raise ArgumentError, 'MoabRecord param required' unless job.arguments.first.is_a?(MoabRecord)
    end

    include UniqueJob

    # @param [MoabRecord] moab_record object to checksum
    def perform(moab_record)
      Audit::ChecksumValidationService.new(moab_record).validate_checksums
    end
  end
end
