module Audit
  # Checksum validator code
  class Checksum
    class << self
      delegate :logger, to: ::PreservationCatalog::Application
    end

    def self.validate_disk(endpoint_name, limit=Settings.c2m_sql_limit)
      logger.info "#{Time.now.utc.iso8601} CV validate_disk starting for #{endpoint_name}"
      # pres_copies is an AR Relation; it could return a lot of results, so we want to process it in
      # batches.  we can't use ActiveRecord's .find_each, because that'll disregard the order .fixity_check_expired
      # specified.  so we use our own batch processing method, which does respect Relation order.
      pres_copies = PreservedCopy.by_endpoint_name(endpoint_name).for_online_endpoints.fixity_check_expired
      logger.info "Number of Preserved Copies to be checksum validated: #{pres_copies.count}"
      ActiveRecordUtils.process_in_batches(pres_copies, limit) do |pc|
        ChecksumValidator.new(pc).validate_checksums
      end
    ensure
      logger.info "#{Time.now.utc.iso8601} CV validate_disk ended for #{endpoint_name}"
    end

    def self.validate_disk_profiled(endpoint_name)
      Profiler.print_profile('cv_validate_disk') { validate_disk(endpoint_name) }
    end

    def self.validate_disk_all_endpoints
      logger.info "#{Time.now.utc.iso8601} CV validate_disk_all_endpoints starting"
      HostSettings.storage_roots.to_h.each_key do |strg_root_name|
        validate_disk(strg_root_name)
      end
    ensure
      logger.info "#{Time.now.utc.iso8601} CV validate_disk_all_endpoints ended"
    end

    def self.validate_disk_all_endpoints_profiled
      Profiler.print_profile('cv_validate_disk_all_endpoints') { validate_disk_all_endpoints }
    end

    def self.validate_druid(druid)
      logger.info "#{Time.now.utc.iso8601} CV validate_druid starting for #{druid}"
      pres_copies = PreservedCopy.by_druid(druid).for_online_endpoints
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

    # validate objects with a particular status on a particular endpoint
    def self.validate_status_root(status, endpoint_name, limit=Settings.c2m_sql_limit)
      # pres_copies is an AR Relation; it could return a lot of results, so we want to process it in
      # batches.  we can't use ActiveRecord's .find_each, because that'll disregard the order .fixity_check_expired
      # specified.  so we use our own batch processing method, which does respect Relation order.
      pres_copies = PreservedCopy.send(status).by_endpoint_name(endpoint_name).for_online_endpoints
      desc = "Number of Preserved Copies of status #{status} from #{endpoint_name} to be checksum validated"
      logger.info "#{desc}: #{pres_copies.count}"
      ActiveRecordUtils.process_in_batches(pres_copies, limit) do |pc|
        logger.info "CV beginning for #{pc.preserved_object.druid}; starting status #{pc.status}"
        ChecksumValidator.new(pc).validate_checksums
        logger.info "CV ended for #{pc.preserved_object.druid}; ending status #{pc.status}"
      end
    end
  end
end
