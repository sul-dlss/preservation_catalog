# frozen_string_literal: true

module Audit
  # Checksum validator code
  class Checksum
    def self.logger
      @logger ||= Logger.new($stdout)
                        .extend(ActiveSupport::Logger.broadcast(Logger.new(Rails.root.join('log', 'cv.log'))))
    end

    # @return [Array<AuditResults>] results from ChecksumValidator runs
    def self.validate_druid(druid)
      logger.info "#{Time.now.utc.iso8601} CV validate_druid starting for #{druid}"
      po = PreservedObject.find_by(druid: druid)
      complete_moab = po&.complete_moab
      logger.debug("#{complete_moab ? 'Found' : 'Did Not Find'} complete moab.")
      if complete_moab
        cv = ChecksumValidator.new(complete_moab)
        cv.validate_checksums
        logger.info "#{cv.results.results} for #{druid}"
        cv.results
      end
    ensure
      logger.warn("No PreservedObject found for #{druid}") unless po
      logger.info "#{Time.now.utc.iso8601} CV validate_druid ended for #{druid}"
    end

    # assumes that the list of druids is in column 1, and has no header.
    def self.validate_list_of_druids(druid_list_file_path)
      CSV.foreach(druid_list_file_path) do |row|
        Checksum.validate_druid(row.first)
      end
    end

    # validate objects with a particular status on a particular moab_storage_root
    def self.validate_status_root(status, storage_root_name)
      raise ArgumentError, "invalid status #{status}" unless CompleteMoab.statuses.key?(status)

      complete_moabs = MoabStorageRoot.find_by!(name: storage_root_name).complete_moabs.where(status: status)
      desc = "Number of Complete Moabs of status #{status} from #{storage_root_name} to be checksum validated"
      logger.info "#{desc}: #{complete_moabs.count}"
      complete_moabs.find_each do |cm|
        ChecksumValidationJob.perform_later(cm)
      end
    end
  end
end
