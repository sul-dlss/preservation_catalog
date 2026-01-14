# frozen_string_literal: true

module Audit
  # Helper methods for invoking Audit::ChecksumValidationService.
  # These are for use from the Rails console; they are not called from the app.
  class ChecksumValidatorUtils
    def self.logger
      @logger ||= ActiveSupport::BroadcastLogger.new(Logger.new($stdout), Logger.new(Rails.root.join('log', 'audit_checksum_validation.log')))
    end

    # @return [Array<Results>] results from Audit::ChecksumValidationService runs
    def self.validate_druid(druid)
      logger.info "#{Time.now.utc.iso8601} CV validate_druid starting for #{druid}"
      preserved_object = PreservedObject.find_by(druid: druid)
      moab_record = preserved_object&.moab_record
      logger.debug("#{moab_record ? 'Found' : 'Did Not Find'} MoabRecord in database.")
      if moab_record
        cv = Audit::ChecksumValidationService.new(moab_record)
        cv.validate_checksums
        logger.info "#{cv.results.to_a} for #{druid}"
        cv.results
      end
    ensure
      logger.warn("No PreservedObject found for #{druid}") unless preserved_object
      logger.info "#{Time.now.utc.iso8601} CV validate_druid ended for #{druid}"
    end

    # assumes that the list of druids is in column 1, and has no header.
    def self.validate_list_of_druids(druid_list_file_path)
      CSV.foreach(druid_list_file_path) do |row|
        validate_druid(row.first)
      end
    end

    # validate objects with a particular status on a particular moab_storage_root
    def self.validate_status_root(status, storage_root_name)
      raise ArgumentError, "invalid status #{status}" unless MoabRecord.statuses.key?(status)

      moab_records = MoabStorageRoot.find_by!(name: storage_root_name).moab_records.where(status: status)
      desc = "Number of MoabRecords of status #{status} from #{storage_root_name} to be checksum validated"
      logger.info "#{desc}: #{moab_records.count}"
      moab_records.find_each do |moab_record|
        Audit::ChecksumValidationJob.perform_later(moab_record)
      end
    end
  end
end
