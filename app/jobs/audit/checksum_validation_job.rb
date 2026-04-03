# frozen_string_literal: true

module Audit
  # Confirm checksum for one Moab on storage and update MoabRecord in database
  # @see Audit::ChecksumValidationService
  class ChecksumValidationJob < ApplicationJob
    queue_as :checksum_validation

    limits_concurrency to: 1, key: ->(job) { job.arguments.first }, duration: 1.hour, on_conflict: :discard

    RETRIES = 5

    # Retriable jobs should retry when any exception is raised. Retry
    # `RETRIES` times, and use exponential backoff so that the tries are
    # spread across a span of roughly ten minutes.
    #
    # If the number of attempts exceeds `RETRIES`, raise the exception.
    #
    # @param [MoabRecord] moab_record object to checksum
    def perform(moab_record)
      tries ||= 0
      Audit::ChecksumValidationService.new(moab_record).validate_checksums
    rescue StandardError
      if (tries += 1) <= RETRIES
        sleep (tries**4) + (Kernel.rand * (tries**3)) + 2
        retry
      end
      raise
    end
  end
end
