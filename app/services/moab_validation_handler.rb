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
    can_do = can_validate_checksums? || preserved_copy.status != PreservedCopy::INVALID_CHECKSUM_STATUS
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
  def set_status_as_seen_on_disk(found_expected_version)
    if moab_validation_errors.any?
      update_status(PreservedCopy::INVALID_MOAB_STATUS)
      return
    end

    unless found_expected_version
      update_status(PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS)
      return
    end

    # TODO: this still isn't quite honest in the cases where checksum validation hasn't been performed
    update_status(PreservedCopy::OK_STATUS)
  end
end
