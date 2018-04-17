##
# mixin with methods for running StorageObjectValidator
module MoabValidationHandler
  # expects the class that mixes this in to have the following methods:
  # #druid
  # #storage_location

  def object_dir
    @object_dir ||= "#{storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
  end

  def moab
    @moab ||= Moab::StorageObject.new(druid, object_dir)
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
end
