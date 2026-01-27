# frozen_string_literal: true

module MoabService
  # Creates a PreservedObject base on a based on a moab on storage.
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
      debugger
      perform_execute do
        if preserved_object_exists?
          report_already_exists
        else
          moab_on_storage_validator.ran_moab_validation! if checksums_validated # ensure validation timestamps updated
          create_db_objects(creation_status(checksums_validated), checksums_validated: checksums_validated)
        end
      end
    end

    private

    def report_already_exists
      results.add_result(Results::DB_OBJ_ALREADY_EXISTS, 'PreservedObject')
    end

    def creation_status(checksums_validated)
      checksums_validated ? 'ok' : 'validity_unknown'
    end
  end
end
