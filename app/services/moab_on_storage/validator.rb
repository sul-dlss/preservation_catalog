# frozen_string_literal: true

# Services for a moab on local storage (as opposed to a moab db record in the catalog or moab replicated to the cloud)
module MoabOnStorage
  # service class with methods for running Stanford::StorageObjectValidator in moab-versioning gem
  class Validator
    # @param moab [Moab::StorageObject] the moab to be validated
    # @param results [Audit::Results] the instance the including class is using to track findings of interest
    def initialize(moab:, audit_results:)
      @moab = moab
      @audit_results = audit_results
    end

    def can_validate_current_comp_moab_status?(moab_record:, caller_validates_checksums: false)
      can_do = caller_validates_checksums || moab_record.status != 'invalid_checksum'
      audit_results.add_result(Audit::Results::UNABLE_TO_CHECK_STATUS, current_status: moab_record.status) unless can_do
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
            audit_results.add_result(Audit::Results::INVALID_MOAB, moab_error_msgs)
          end
          moab_errors
        end
    end

    def ran_moab_validation?
      @ran_moab_validation ||= false
    end

    def ran_moab_validation!
      @ran_moab_validation = true
    end

    private

    attr_reader :moab, :audit_results
  end
end
