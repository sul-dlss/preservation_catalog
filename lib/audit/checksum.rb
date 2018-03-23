require 'active_record_utils.rb'
require 'profiler.rb'

# Checksum validator code
class Checksum

  def self.validate_disk(endpoint_name, limit=Settings.c2m_sql_limit)
    start_msg = "#{Time.now.utc.iso8601} CV validate_disk starting for #{endpoint_name}"
    puts start_msg
    Rails.logger.info start_msg

    # pcs_w_expired_fixity_check is an AR Relation; it could return a lot of results, so we want to process it in
    # batches.  we can't use ActiveRecord's .find_each, because that'll disregard the order .fixity_check_expired
    # specified.  so we use our own batch processing method, which does respect Relation order.
    pcs_w_expired_fixity_check = PreservedCopy.by_endpoint_name(endpoint_name).fixity_check_expired
    ActiveRecordUtils.process_in_batches(pcs_w_expired_fixity_check, limit) do |pc|
      cv = ChecksumValidator.new(pc, endpoint_name)
      cv.validate_checksums
    end

    end_msg = "#{Time.now.utc.iso8601} CV validate_disk ended for #{endpoint_name}"
    puts end_msg
    Rails.logger.info end_msg
  end

  def self.validate_disk_profiled(endpoint_name)
    profiler = Profiler.new
    profiler.prof { validate_disk(endpoint_name) }
    profiler.print_results_flat('cv_validate_disk')
  end

  def self.validate_disk_all_endpoints
    start_msg = "#{Time.now.utc.iso8601} CV validate_disk_all_endpoints starting"
    puts start_msg
    Rails.logger.info start_msg
    Settings.moab.storage_roots.each do |strg_root_name, _strg_root_location|
      validate_disk(strg_root_name)
    end
    end_msg = "#{Time.now.utc.iso8601} CV validate_disk_all_endpoints ended"
    puts end_msg
    Rails.logger.info end_msg
  end

  def self.validate_disk_all_endpoints_profiled
    profiler = Profiler.new
    profiler.prof { validate_disk_all_endpoints }
    profiler.print_results_flat('cv_validate_disk_all_endpoints')
  end

  def self.validate_druid(druid)
    start_msg = "#{Time.now.utc.iso8601} CV validate_druid starting for #{druid}"
    puts start_msg
    Rails.logger.info start_msg
    pres_copies = PreservedCopy.by_druid(druid)
    Rails.logger.error("Found #{pres_copies.size} preserved copies.") if pres_copies.empty?
    pres_copies.each do |pc|
      endpoint_name = pc.endpoint.endpoint_name
      cv = ChecksumValidator.new(pc, endpoint_name)
      cv.validate_checksums
    end
    end_msg = "#{Time.now.utc.iso8601} CV validate_druid ended for #{druid}"
    puts end_msg
    Rails.logger.info end_msg
  end

end
