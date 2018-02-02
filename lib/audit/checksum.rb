require 'profiler.rb'

# Checksum validator code
class Checksum

  # FIXME: remove rubocop exception once we start filling these methods in
  # rubocop:disable Lint/UnusedMethodArgument
  # rubocop:disable Style/EmptyMethod:
  # TODO: implement this;  we begin with a placeholder

  def self.checksum_validate_disk(last_checked_b4, endpoint, algorithm="MD5")
  end

  def self.checksum_validate_disk_profiled(last_checked_b4, endpoint, algorithm)
    profiler = Profiler.new
    profiler.prof { checksum_validate_disk(last_checked_b4, endpoint, algorithm) }
    profiler.print_results_flat('CV_checksum_validation_on_dir')
  end

  def self.checksum_validate_disk_all_endpoints(last_checked_b4, algorithm="md5")
  end

  def self.checksum_validate_disk_all_endpoints_profiled(last_checked_b4, algorithm)
    profiler = Profiler.new
    profiler.prof { checksum_validate_disk_all_endpoints(last_checked_b4, algorithm) }
    profiler.print_results_flat('CV_checksum_validation_all_endpoints')
  end

end
