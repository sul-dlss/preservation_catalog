# frozen_string_literal: true

module CompleteMoabService
  # Creates CompletedMoab and associated objects based on a moab on disk after validation of moab.
  class CreateAfterValidation < Create
    def self.execute(druid:, incoming_version:, incoming_size:, moab_storage_root:, checksums_validated: false)
      new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size,
          moab_storage_root: moab_storage_root).execute(checksums_validated: checksums_validated)
    end

    def initialize(druid:, incoming_version:, incoming_size:, moab_storage_root:, check_name: 'create_after_validation')
      super
    end

    private

    # This overrides creation_status in the parent class, providing the "after validation" behavior.
    def creation_status(checksum_validated)
      return 'invalid_moab' if moab_validator.moab_validation_errors.present?
      super
    end
  end
end
