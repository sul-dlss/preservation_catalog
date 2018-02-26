require 'profiler.rb'

# Checksum validator code
class Checksum

  # FIXME: remove rubocop exception once we start filling these methods in
  # rubocop:disable Lint/UnusedMethodArgument
  # rubocop:disable Style/EmptyMethod:
  # TODO: implement this;  we begin with a placeholder

  def self.validate_disk(last_checked_b4, storage_dir)
  end

  def self.validate_disk_profiled(last_checked_b4, storage_dir)
    profiler = Profiler.new
    profiler.prof { validate_disk(last_checked_b4, storage_dir) }
    profiler.print_results_flat('CV_checksum_validation_on_dir')
  end

  def self.validate_disk_all_dirs(last_checked_b4)
  end

  def self.validate_disk_all_dirs_profiled(last_checked_b4)
    profiler = Profiler.new
    profiler.prof { validate_disk_all_dirs(last_checked_b4) }
    profiler.print_results_flat('CV_checksum_validation_all_dirs')
  end

end
