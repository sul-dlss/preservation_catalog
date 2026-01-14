# frozen_string_literal: true

module ResultsReporters
  # Reports to Honeybadger.
  class HoneybadgerReporter < BaseReporter
    private

    def handled_single_codes
      [
        Audit::Results::DB_OBJ_ALREADY_EXISTS,
        Audit::Results::MOAB_FILE_CHECKSUM_MISMATCH,
        Audit::Results::MOAB_NOT_FOUND,
        Audit::Results::ZIP_PART_CHECKSUM_MISMATCH,
        Audit::Results::ZIP_PART_NOT_FOUND,
        Audit::Results::ZIP_PARTS_COUNT_DIFFERS_FROM_ACTUAL,
        Audit::Results::ZIP_PARTS_NOT_ALL_REPLICATED,
        Audit::Results::ZIP_PARTS_SIZE_INCONSISTENCY
      ].freeze
    end

    def handle_completed(...)
      # Pass
    end

    def handle_single_error(druid, _version, storage_area, check_name, result)
      Honeybadger.notify(
        check_name,
        context: {
          druid:,
          storage_area: storage_area.to_s,
          result: result.values.first
        }
      )
    end
  end
end
