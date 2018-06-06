require 'profiler.rb'
require 'csv'

# Checksum validator code
class Checksum
  class << self
    delegate :logger, to: PreservationCatalog::Application
  end

  def self.validate_disk(endpoint_name, limit=Settings.c2m_sql_limit)
    logger.info "#{Time.now.utc.iso8601} CV validate_disk starting for #{endpoint_name}"
    # pcs_w_expired_fixity_check is an AR Relation; it could return a lot of results, so we want to process it in
    # batches.  we can't use ActiveRecord's .find_each, because that'll disregard the order .fixity_check_expired
    # specified.  so we use our own batch processing method, which does respect Relation order.
    pcs_w_expired_fixity_check = PreservedCopy.by_endpoint_name(endpoint_name).fixity_check_expired
    logger.info "Number of Preserved Copies to be checksum validated: #{pcs_w_expired_fixity_check.count}"
    ActiveRecordUtils.process_in_batches(pcs_w_expired_fixity_check, limit) do |pc|
      cv = ChecksumValidator.new(pc, endpoint_name)
      cv.validate_checksums
    end
  ensure
    logger.info "#{Time.now.utc.iso8601} CV validate_disk ended for #{endpoint_name}"
  end

  def self.validate_disk_profiled(endpoint_name)
    profiler = Profiler.new
    profiler.prof { validate_disk(endpoint_name) }
    profiler.print_results_flat('cv_validate_disk')
  end

  def self.validate_disk_all_endpoints
    logger.info "#{Time.now.utc.iso8601} CV validate_disk_all_endpoints starting"
    HostSettings.storage_roots.each do |strg_root_name, _strg_root_location|
      validate_disk(strg_root_name)
    end
  ensure
    logger.info "#{Time.now.utc.iso8601} CV validate_disk_all_endpoints ended"
  end

  def self.validate_disk_all_endpoints_profiled
    profiler = Profiler.new
    profiler.prof { validate_disk_all_endpoints }
    profiler.print_results_flat('cv_validate_disk_all_endpoints')
  end

  def self.validate_druid(druid)
    logger.info "#{Time.now.utc.iso8601} CV validate_druid starting for #{druid}"
    pres_copies = PreservedCopy.by_druid(druid)
    Rails.logger.debug("Found #{pres_copies.size} preserved copies.")
    checksum_results_lists = []
    pres_copies.each do |pc|
      endpoint_name = pc.endpoint.endpoint_name
      cv = ChecksumValidator.new(pc, endpoint_name)
      cv.validate_checksums
      checksum_results_lists << cv.results
      logger.info cv.results.result_array
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
end
