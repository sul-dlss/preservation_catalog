# frozen_string_literal: true

module AuditReporters
  # Reports to Honeybadger.
  class HoneybadgerReporter < BaseReporter
    protected

    def handled_single_codes
      [
        Audit::Results::DB_OBJ_ALREADY_EXISTS,
        Audit::Results::MOAB_FILE_CHECKSUM_MISMATCH,
        Audit::Results::MOAB_NOT_FOUND,
        Audit::Results::ZIP_PART_CHECKSUM_MISMATCH,
        Audit::Results::ZIP_PART_NOT_FOUND,
        Audit::Results::ZIP_PARTS_COUNT_DIFFERS_FROM_ACTUAL,
        Audit::Results::ZIP_PARTS_COUNT_INCONSISTENCY,
        Audit::Results::ZIP_PARTS_NOT_ALL_REPLICATED,
        Audit::Results::ZIP_PARTS_SIZE_INCONSISTENCY
      ].freeze
    end

    def handle_completed(druid, version, storage_area, check_name, result)
      # Pass
    end

    def handle_single_error(druid, _version, storage_area, check_name, result)
      Honeybadger.notify("#{check_name}(#{druid}, #{storage_area&.to_s}) #{result.values.first}")
    end
  end
end
