# frozen_string_literal: true

module AuditReporters
  # Reports to logger.
  class LoggerReporter < BaseReporter
    def initialize(logger = nil) # rubocop:disable Lint/MissingSuper
      @logger = logger || Rails.logger
    end

    protected

    def handled_single_codes
      # Everything
      nil
    end

    def handle_completed(druid, _version, storage_area, check_name, result)
      log(druid, storage_area, check_name, result)
    end

    def handle_single_error(druid, _version, storage_area, check_name, result)
      log(druid, storage_area, check_name, result)
    end

    private

    attr_reader :logger

    def log(druid, storage_area, check_name, result)
      severity = logger_severity_level(result.keys.first)
      logger.add(severity, "#{check_name}(#{druid.delete_prefix('druid:')}, #{storage_area&.to_s}) #{result.values.first}")
    end

    def logger_severity_level(result_code)
      case result_code
      when Audit::Results::DB_OBJ_DOES_NOT_EXIST, Audit::Results::ZIP_PARTS_NOT_CREATED, Audit::Results::ZIP_PARTS_NOT_ALL_REPLICATED
        Logger::WARN
      when Audit::Results::VERSION_MATCHES, Audit::Results::ACTUAL_VERS_GT_DB_OBJ, Audit::Results::CREATED_NEW_OBJECT,
          Audit::Results::MOAB_RECORD_STATUS_CHANGED, Audit::Results::MOAB_CHECKSUM_VALID
        Logger::INFO
      else
        Logger::ERROR
      end
    end
  end
end
