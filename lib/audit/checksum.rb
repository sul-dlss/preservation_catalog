require 'profiler.rb'

# Checksum validator code
class Checksum

  def self.validate_disk(endpoint_name, limit=Settings.c2m_sql_limit)
    start_msg = "#{Time.now.utc.iso8601} CV validate_disk starting for #{endpoint_name}"
    puts start_msg
    Rails.logger.info start_msg
    all_processable_copies = PreservedCopy.by_endpoint_name(endpoint_name).fixity_check_expired
    num_to_process = all_processable_copies.count
    while num_to_process > 0
      pcs = all_processable_copies.limit(limit)
      pcs.each do |pc|
        cv = ChecksumValidator.new(pc, endpoint_name)
        cv.validate_checksum
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
    Settings.moab.storage_roots.each do |_strg_root_name, strg_root_location|
      validate_disk("#{strg_root_location}/#{Settings.moab.storage_trunk}")
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

end
