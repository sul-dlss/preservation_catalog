require 'profiler.rb'

# Checksum validator code
class Checksum

  def self.validate_disk(endpoint_name, limit=Settings.c2m_sql_limit)
    start_msg = "#{Time.now.utc.iso8601} CV validate_disk starting for #{endpoint_name}"
    puts start_msg
    Rails.logger.info start_msg

    # pcs_w_expired_fixity_check is an AR relation; fine to run it with a .count or a .limit tacked on, but
    # don't call .each directly on it and get the whole result set at once. Also, don't call .for_each or
    # the ordering of the results will be lost.
    pcs_w_expired_fixity_check = PreservedCopy.by_endpoint_name(endpoint_name).fixity_check_expired
    num_to_process = pcs_w_expired_fixity_check.count
    while num_to_process > 0
      pcs_for_batch = pcs_w_expired_fixity_check.limit(limit)
      pcs_for_batch.each do |pc|
        cv = ChecksumValidator.new(pc, endpoint_name)
        cv.validate_checksums
      end
      num_to_process -= limit
    end
    end_msg = "#{Time.now.utc.iso8601} CV validate_disk ended for #{endpoint_name}"
    puts end_msg
    Rails.logger.info end_msg
  end

  def self.validate_disk_profiled(endpoint_name)
    profiler = Profiler.new
    profiler.prof { validate_disk(endpoint_name) }
    profiler.print_results_flat('CV_checksum_validation_on_endpoint')
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
    profiler.print_results_flat('CV_checksum_validation_all_endpoints')
  end

  def self.validate_druid(druid)
    start_msg = "#{Time.now.utc.iso8601} CV validate_druid starting for #{druid}"
    puts start_msg
    Rails.logger.info start_msg
    po = PreservedObject.find_by(druid: druid)
    pres_copy = PreservedCopy.find_by(preserved_object: po)
    endpoint_name = pres_copy.endpoint.endpoint_name
    cv = ChecksumValidator.new(pres_copy, endpoint_name)
    cv.validate_checksums
    end_msg = "#{Time.now.utc.iso8601} CV validate_druid ended for #{druid}"
    puts end_msg
    Rails.logger.info end_msg
  end

end
