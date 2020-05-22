# frozen_string_literal: true

module Audit
  # Checksum validator code
  class Checksum
    def self.logger
      @logger ||= Logger.new(STDOUT)
                        .extend(ActiveSupport::Logger.broadcast(Logger.new(Rails.root.join('log', 'cv.log'))))
    end

    # @return [Array<AuditResults>] results from ChecksumValidator runs
    def self.validate_druid(druid)
      logger.info "#{Time.now.utc.iso8601} CV validate_druid starting for #{druid}"
      po = PreservedObject.find_by(druid: druid)
      complete_moabs = po ? po.complete_moabs : []
      logger.debug("Found #{complete_moabs.size} complete moabs.")
      complete_moabs.map do |cm|
        cv = ChecksumValidator.new(cm)
        cv.validate_checksums
        logger.info "#{cv.results.result_array} for #{druid}"
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
    def self.validate_status_root(status, storage_root_name, limit = Settings.c2m_sql_limit)
      # complete_moabs is an AR Relation; it could return a lot of results, so we want to process it in
      # batches.  we can't use ActiveRecord's .find_each, because that'll disregard the order .fixity_check_expired
      # specified.  so we use our own batch processing method, which does respect Relation order.
      complete_moabs = MoabStorageRoot.find_by!(name: storage_root_name).complete_moabs.where(status: status)
      desc = "Number of Complete Moabs of status #{status} from #{storage_root_name} to be checksum validated"
      logger.info "#{desc}: #{complete_moabs.count}"
      ActiveRecordUtils.process_in_batches(complete_moabs, limit) do |cm|
        logger.info "CV beginning for #{cm.preserved_object.druid}; starting status #{cm.status}"
        ChecksumValidator.new(cm).validate_checksums
        logger.info "CV ended for #{cm.preserved_object.druid}; ending status #{cm.status}"
      end
    end
  end
end
