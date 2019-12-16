# frozen_string_literal: true

# Validate moabs
class MoabValidator
  attr_reader :audit_results, :complete_moab, :druid

  def initialize(audit_results:, complete_moab:, druid:)
    @audit_results = audit_results
    @complete_moab = complete_moab
    @druid = druid
  end

  def ran_moab_validation!
    @ran_moab_validation = true
  end

  def ran_moab_validation?
    @ran_moab_validation ||= false
  end

  def object_dir
    @object_dir ||= "#{complete_moab.moab_storage_root.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
  end

  def moab
    @moab ||= Moab::StorageObject.new(druid, object_dir)
  end

  def update_status(new_status)
    complete_moab.status = new_status
    return unless complete_moab.status_changed?

    audit_results.add_result(
      AuditResults::CM_STATUS_CHANGED, old_status: complete_moab.status_was, new_status: complete_moab.status
    )
  end

  def can_validate_checksums?
    false
  end

  def can_validate_current_comp_moab_status?
    can_do = can_validate_checksums? || complete_moab.status != 'invalid_checksum'
    audit_results.add_result(AuditResults::UNABLE_TO_CHECK_STATUS, current_status: complete_moab.status) unless can_do
    can_do
  end

  def moab_validation_errors
    @moab_validation_errors ||=
      begin
        object_validator = Stanford::StorageObjectValidator.new(moab)
        moab_errors = object_validator.validation_errors(Settings.moab.allow_content_subdirs)
        ran_moab_validation!
        if moab_errors.any?
          moab_error_msgs = []
          moab_errors.each do |error_hash|
            moab_error_msgs += error_hash.values
          end
          audit_results.add_result(AuditResults::INVALID_MOAB, moab_error_msgs)
        end
        moab_errors
      end
  end

  # found_expected_version is a boolean indicating whether the latest version of the moab
  # on disk is the expected version according to the catalog.  NOTE: in the case of an update
  # this might mean the on disk version is one higher than the catalog version, if the
  # catalog hasn't been updated yet.
  # @param [Boolean] found_expected_version
  # @return [void]
  def set_status_as_seen_on_disk(found_expected_version)
    begin
      return update_status('invalid_moab') if moab_validation_errors.any?
    rescue Errno::ENOENT
      audit_results.add_result(AuditResults::MOAB_NOT_FOUND,
                               db_created_at: complete_moab.created_at.iso8601,
                               db_updated_at: complete_moab.updated_at.iso8601)
      return update_status('online_moab_not_found')
    end

    return update_status('unexpected_version_on_storage') unless found_expected_version

    # NOTE: subclasses which override this method should NOT perform checksum validation inside of this method!
    # CV is expensive, and can run a while, and this method should likely be called from within a DB transaction,
    # but CV definitely shouldn't happen inside a DB transaction.
    if audit_results.contains_result_code?(AuditResults::MOAB_CHECKSUM_VALID)
      update_status('ok')
    elsif can_validate_checksums?
      update_status('invalid_checksum')
    else
      update_status('validity_unknown')
    end
  end
end
