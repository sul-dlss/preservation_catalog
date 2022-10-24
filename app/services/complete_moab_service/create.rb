# frozen_string_literal: true

module CompleteMoabService
  # Creates CompletedMoab and associated objects based on a moab on disk.
  class Create < Base
    def self.execute(druid:, incoming_version:, incoming_size:, moab_storage_root:, checksums_validated: false)
      new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size,
          moab_storage_root: moab_storage_root).execute(checksums_validated: checksums_validated)
    end

    def initialize(druid:, incoming_version:, incoming_size:, moab_storage_root:, check_name: 'create')
      super
    end

    # checksums_validated may be set to true if the caller takes responsibility for having validated the checksums
    def execute(checksums_validated: false)
      perform_execute do
        if CompleteMoab.by_druid(druid).by_storage_root(moab_storage_root).exists?
          results.add_result(AuditResults::DB_OBJ_ALREADY_EXISTS, 'CompleteMoab')
        else
          creation_status = (checksums_validated ? 'ok' : 'validity_unknown')
          moab_validator.ran_moab_validation! if checksums_validated # ensure validation timestamps updated
          create_db_objects(creation_status, checksums_validated: checksums_validated)
        end
      end
    end
  end
end
