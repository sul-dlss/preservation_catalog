require 'profiler.rb'

# Checksum validator code
class Checksum

  # FIXME: remove rubocop exception once we start filling these methods in
  # rubocop:disable Lint/UnusedMethodArgument
  # rubocop:disable Style/EmptyMethod:
  # TODO: implement this;  we begin with a placeholder

  def self.validate_disk(endpoint_name)
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
