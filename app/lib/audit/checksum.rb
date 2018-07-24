module Audit
  # Checksum validator code
  class Checksum

    def self.logger
      @logger ||= Logger.new(STDOUT)
                        .extend(ActiveSupport::Logger.broadcast(Logger.new(Rails.root.join('log', 'cv.log'))))
    end

    # Queues asynchronous CV
    def self.validate_disk(storage_root_name)
      logger.info "#{Time.now.utc.iso8601} CV validate_disk starting for #{storage_root_name}"
      pres_copies = PreservedCopy.by_moab_storage_root_name(storage_root_name).fixity_check_expired
      logger.info "Number of Preserved Copies to be enqueued for CV: #{pres_copies.count}"
      pres_copies.find_each(&:validate_checksums!)
    ensure
      logger.info "#{Time.now.utc.iso8601} CV validate_disk for #{storage_root_name}"
    end

    # Asynchronous
    def self.validate_disk_all_storage_roots
      logger.info "#{Time.now.utc.iso8601} CV validate_disk_all_storage_roots starting"
      HostSettings.storage_roots.to_h.each_key { |key| validate_disk(key) }
    ensure
      logger.info "#{Time.now.utc.iso8601} CV validate_disk_all_storage_roots ended"
    end

    def self.validate_druid(druid)
      logger.info "#{Time.now.utc.iso8601} CV validate_druid starting for #{druid}"
      pres_copies = PreservedCopy.by_druid(druid)
      logger.debug("Found #{pres_copies.size} preserved copies.")
      checksum_results_lists = []
      pres_copies.each do |pc|
        cv = ChecksumValidator.new(pc)
        cv.validate_checksums
        checksum_results_lists << cv.results
        logger.info "#{cv.results.result_array} for #{druid}"
      end
      checksum_results_lists
    ensure
      logger.info "#{Time.now.utc.iso8601} CV validate_druid ended for #{druid}"
    end

    # assumes that the list of druids is in column 1, and has no header.
    def self.validate_list_of_druids(druid_list_file_path)
      CSV.foreach(druid_list_file_path) do |row|
        Checksum.validate_druid(row.first)
      end
    end

    # validate objects with a particular status on a particular moab_storage_root
    def self.validate_status_root(status, storage_root_name, limit=Settings.c2m_sql_limit)
      # pres_copies is an AR Relation; it could return a lot of results, so we want to process it in
      # batches.  we can't use ActiveRecord's .find_each, because that'll disregard the order .fixity_check_expired
      # specified.  so we use our own batch processing method, which does respect Relation order.
      pres_copies = PreservedCopy.send(status).by_moab_storage_root_name(storage_root_name)
      desc = "Number of Preserved Copies of status #{status} from #{storage_root_name} to be checksum validated"
      logger.info "#{desc}: #{pres_copies.count}"
      ActiveRecordUtils.process_in_batches(pres_copies, limit) do |pc|
        logger.info "CV beginning for #{pc.preserved_object.druid}; starting status #{pc.status}"
        ChecksumValidator.new(pc).validate_checksums
        logger.info "CV ended for #{pc.preserved_object.druid}; ending status #{pc.status}"
      end
    end
  end
end
