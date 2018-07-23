##
# mixin with methods for running StorageObjectValidator
module MoabValidationHandler
  # expects the class that includes this module to have the following methods:
  # #druid - String (the "bare" druid, e.g. 'ab123cd4567', sans 'druid:' prefix)
  # #storage_location - String - the root directory holding the druid tree (the storage root path)
  # #results - AuditResults - the instance the including class is using to track findings of interest
  # #preserved_copy - PreservedCopy - instance of the pres copy being validated

  def object_dir
    @object_dir ||= "#{storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
  end

  def moab
    @moab ||= Moab::StorageObject.new(druid, object_dir)
  end

  def can_validate_checksums?
    false
  end

  def can_validate_current_pres_copy_status?
    can_do = can_validate_checksums? || preserved_copy.status != 'invalid_checksum'
    results.add_result(AuditResults::UNABLE_TO_CHECK_STATUS, current_status: preserved_copy.status) unless can_do
    can_do
  end

  def moab_validation_errors
    @moab_errors ||=
      begin
        object_validator = Stanford::StorageObjectValidator.new(moab)
        moab_errors = object_validator.validation_errors(Settings.moab.allow_content_subdirs)
        ran_moab_validation!
        if moab_errors.any?
          moab_error_msgs = []
          moab_errors.each do |error_hash|
            error_hash.each_value { |msg| moab_error_msgs << msg }
          end
          results.add_result(AuditResults::INVALID_MOAB, moab_error_msgs)
        end
        moab_errors
      end
  end

  def ran_moab_validation!
    @ran_moab_validation = true
  end

  def ran_moab_validation?
    @ran_moab_validation ||= false
  end

  def update_status(new_status)
    preserved_copy.update_status(new_status) do
      results.add_result(
        AuditResults::PC_STATUS_CHANGED, old_status: preserved_copy.status, new_status: new_status
      )
    end
  end

  # found_expected_version is a boolean indicating whether the latest version of the moab
  # on disk is the expected version according to the catalog.  NOTE: in the case of an update
  # this might mean the on disk version is one higher than the catalog version, if the
  # catalog hasn't been updated yet.
  # @param [Boolean] found_expected_version
  # @return [void]
  def set_status_as_seen_on_disk(found_expected_version)
    return update_status('invalid_moab') if moab_validation_errors.any?
    return update_status('unexpected_version_on_storage') unless found_expected_version

    # NOTE: subclasses which override this method should NOT perform checksum validation inside of this method!
    # CV is expensive, and can run a while, and this method should likely be called from within a DB transaction,
    # but CV definitely shouldn't happen inside a DB transaction.
    if results.contains_result_code?(AuditResults::MOAB_CHECKSUM_VALID)
      update_status('ok')
    elsif can_validate_checksums?
      update_status('invalid_checksum')
    else
      update_status('validity_unknown')
    end
  end
end
