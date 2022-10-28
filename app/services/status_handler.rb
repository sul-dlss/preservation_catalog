# frozen_string_literal: true

##
# service class for updating status in AuditResults and CompleteMoab
class StatusHandler
  delegate :add_result, to: :audit_results

  # @param results [AuditResults] the instance the including class is using to track findings of interest
  # @param complete_moab [CompleteMoab] instance of the complete moab being validated
  def initialize(audit_results:, complete_moab:)
    @audit_results = audit_results
    @complete_moab = complete_moab
  end

  def update_status(new_status)
    complete_moab.status = new_status

    if complete_moab.status_changed?
      add_result(
        AuditResults::CM_STATUS_CHANGED, old_status: complete_moab.status_was, new_status: complete_moab.status
      )
    end

    complete_moab.status_details = audit_results.results_as_string
  end

  def mark_moab_not_found
    add_result(AuditResults::MOAB_NOT_FOUND,
               db_created_at: complete_moab.created_at.iso8601,
               db_updated_at: complete_moab.updated_at.iso8601)
    update_status('online_moab_not_found')
  end

  # found_expected_version is a boolean indicating whether the latest version of the moab
  # on disk is the expected version according to the catalog.  NOTE: in the case of an update
  # this might mean the on disk version is one higher than the catalog version, if the
  # catalog hasn't been updated yet.
  # @param [Boolean] found_expected_version
  # @params [MoabValidator] moab_validator
  # @caller_validates_checksums [Boolean] defaults to false.  was this called by code that re-computes checksums to confirm that they match the
  #   values listed in the manifests?
  # @return [void]
  def set_status_as_seen_on_disk(found_expected_version:, moab_validator:, caller_validates_checksums: false)
    begin
      return update_status('invalid_moab') if moab_validator.moab_validation_errors.any?
    rescue Errno::ENOENT
      return mark_moab_not_found
    end

    return update_status('unexpected_version_on_storage') unless found_expected_version

    # NOTE: subclasses which override this method should NOT perform checksum validation inside of this method!
    # CV is expensive, and can run a while, and this method should likely be called from within a DB transaction,
    # but CV definitely shouldn't happen inside a DB transaction.
    if audit_results.contains_result_code?(AuditResults::MOAB_CHECKSUM_VALID)
      update_status('ok')
    elsif caller_validates_checksums
      update_status('invalid_checksum')
    else
      update_status('validity_unknown')
    end
  end

  private

  attr_reader :complete_moab, :audit_results
end
