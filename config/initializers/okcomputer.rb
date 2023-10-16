# frozen_string_literal: true

require 'okcomputer'

OkComputer.mount_at = 'status' # use /status or /status/all or /status/<name-of-check>
OkComputer.check_in_parallel = true

def worker_host?
  Settings.worker_hostnames.include?(Socket.gethostname)
end

# check models to see if at least they have some data
class TablesHaveDataCheck < OkComputer::Check
  def check
    mark_message table_check(MoabStorageRoot)
  end

  private

  # @return [String] message
  def table_check(klass)
    # has at least 1 record, using select(:id) to avoid returning all data
    return "#{klass.name} has data." if klass.select(:id).first!.present?

    mark_failure
    "#{klass.name} has no data."
  rescue ActiveRecord::RecordNotFound
    mark_failure
    "#{klass.name} has no data."
  rescue => e # rubocop:disable Style/RescueStandardError
    mark_failure
    "#{e.class.name} received: #{e.message}."
  end
end
OkComputer::Registry.register 'feature-tables-have-data', TablesHaveDataCheck.new

# check that directory is accessible without consideration for writability
class DirectoryExistsCheck < OkComputer::Check
  attr_accessor :directory, :min_subfolder_count

  def initialize(directory, min_subfolder_count = nil)
    self.directory = directory
    self.min_subfolder_count = min_subfolder_count
  end

  def check
    unless File.exist? directory
      mark_message "Directory '#{directory}' does not exist."
      mark_failure
    end

    unless File.directory? directory
      mark_message "'#{directory}' is not a directory."
      mark_failure
    end

    mark_message "'#{directory}' is a reachable directory"
    if min_subfolder_count && Dir.entries(directory).size > min_subfolder_count
      mark_message "'#{directory}' has the required minimum number of subfolders (#{min_subfolder_count})"
    elsif min_subfolder_count
      mark_message "'#{directory}' does not have the required minimum number of subfolders (#{min_subfolder_count})"
      mark_failure
    end
  end
end
Settings.storage_root_map.default.each do |name, location|
  sdrobjects_location = "#{location}/#{Settings.moab.storage_trunk}"
  OkComputer::Registry.register "feature-#{name}-sdr2objects", DirectoryExistsCheck.new(sdrobjects_location, Settings.minimum_subfolder_count)
end

OkComputer::Registry.register 'ruby_version', OkComputer::RubyVersionCheck.new

# confirm that the expected number of sidekiq worker processes and threads are running
class SidekiqWorkerCountCheck < OkComputer::Check
  class ExpectedEnvVarMissing < StandardError; end

  def check
    actual_local_sidekiq_processes = fetch_local_sidekiq_processes
    actual_local_sidekiq_process_count = actual_local_sidekiq_processes.size
    actual_local_total_concurrency = actual_local_sidekiq_processes.sum { |process| process['concurrency'] }

    error_list = calculate_error_list(actual_local_sidekiq_process_count: actual_local_sidekiq_process_count,
                                      actual_local_total_concurrency: actual_local_total_concurrency)

    if error_list.empty?
      mark_message "Sidekiq worker counts as expected on this VM: #{actual_local_sidekiq_process_count} worker " \
                   "processes, #{actual_local_total_concurrency} concurrent worker threads total."
    else
      mark_message error_list.join('  ')
      mark_failure
    end
  rescue ExpectedEnvVarMissing => e
    mark_message e.message
    mark_failure
  end

  private

  # @return [Array<Sidekiq::Process>] one Sidekiq::Process object for each worker management
  #   process currently running on _this_ VM
  def fetch_local_sidekiq_processes
    fetch_global_sidekiq_process_list.select do |p|
      p['hostname'] == Socket.gethostname
    end
  end

  # @return [Array<Sidekiq::Process>] one Sidekiq::Process object for each worker management
  #   process currently running on _all_ worker VMs
  def fetch_global_sidekiq_process_list
    # Sidekiq::ProcessSet#each doesn't return an Enumerator, it just loops and calls the block it's passed
    [].tap do |pset_list|
      Sidekiq::ProcessSet.new.each { |process| pset_list << process }
    end
  end

  # the number of concurrent Sidekiq worker threads per process is set in config/sidekiq.yml
  def expected_sidekiq_proc_concurrency(proc_num: nil)
    config_filename = proc_num.present? ? "../../shared/config/sidekiq#{proc_num}.yml" : 'config/sidekiq.yml'
    sidekiq_config = YAML.safe_load(Rails.root.join(config_filename).read, permitted_classes: [Symbol])
    sidekiq_config[:concurrency]
  end

  # puppet runs a number of sidekiq processes using systemd, exposing the expected process count via env var
  def expected_sidekiq_process_count
    @expected_sidekiq_process_count ||= Integer(ENV.fetch('EXPECTED_SIDEKIQ_PROC_COUNT'))
  rescue StandardError => e
    err_description = 'Error retrieving EXPECTED_SIDEKIQ_PROC_COUNT and parsing to int. ' \
                      "ENV['EXPECTED_SIDEKIQ_PROC_COUNT']=#{ENV.fetch('EXPECTED_SIDEKIQ_PROC_COUNT', nil)}"
    Rails.logger.error("#{err_description} -- #{e.message} -- #{e.backtrace}")
    raise ExpectedEnvVarMissing, err_description
  end

  def expected_local_total_concurrency
    # Existence of config/sidekiq.yml indicates a single config for all sidekiq processes. otherwise, each of
    # the sidekiq processes, 1 through EXPECTED_SIDEKIQ_PROC_COUNT, will have its own config file.
    # The number of sidekiq[N].yml files may not match the number of sidekiq processes if custom_execstart=false
    # in puppet config.
    @expected_local_total_concurrency ||=
      if File.exist?('config/sidekiq.yml')
        expected_sidekiq_process_count * expected_sidekiq_proc_concurrency
      else
        (1..expected_sidekiq_process_count).sum { |n| expected_sidekiq_proc_concurrency(proc_num: n) }
      end
  end

  def calculate_error_list(actual_local_sidekiq_process_count:, actual_local_total_concurrency:)
    error_list = []

    if actual_local_sidekiq_process_count > expected_sidekiq_process_count
      error_list << <<~ERR_TXT
        Actual Sidekiq worker process count (#{actual_local_sidekiq_process_count}) on this VM is greater than \
        expected (#{expected_sidekiq_process_count}). Check for stale Sidekiq processes (e.g. from old deployments). \
        It's also possible that some worker threads are finishing WIP that started before a Sidekiq restart, e.g. as \
        happens when long running job spans app deployment. Use your judgement when deciding whether to kill an old process.
      ERR_TXT
    end
    if actual_local_sidekiq_process_count < expected_sidekiq_process_count
      error_list << "Actual Sidekiq worker management process count (#{actual_local_sidekiq_process_count}) on " \
                    "this VM is less than expected (#{expected_sidekiq_process_count})."
    end
    if actual_local_total_concurrency != expected_local_total_concurrency
      error_list << "Actual worker thread count on this VM is #{actual_local_total_concurrency}, but " \
                    "expected local total Sidekiq concurrency is #{expected_local_total_concurrency}."
    end

    error_list
  end
end

# we don't want to register this on non-worker boxes, because it only tracks local worker processes
OkComputer::Registry.register 'sidekiq_worker_count', SidekiqWorkerCountCheck.new if worker_host?

# ------------------------------------------------------------------------------

# NON-CRUCIAL (Optional) checks, avail at /status/<name-of-check>
#   - at individual moab_storage_root, HTTP response code reflects the actual result
#   - in /status/all, these checks will display their result text, but will not affect HTTP response code

# Audit Checks (only) report errors to workflow service so they appear in Argo
workflows_url = "#{Settings.workflow_services_url}/objects/druid:oo000oo0000/workflows"
OkComputer::Registry.register 'external-workflow-services-url', OkComputer::HttpCheck.new(workflows_url)

# For each deployed environment (qa, stage, prod), the "web" host, by convention, does not
# mount the zip-transfers directory, so this check will always fail on those hosts. Instead
# of failing a check on these hosts, only register the check on non-web hosts.
if worker_host?
  # Replication (only) uses zip_storage directory to build the zips to send to zip endpoints
  OkComputer::Registry.register 'feature-zip_storage_dir', OkComputer::DirectoryCheck.new(Settings.zip_storage)
end

# TODO: do we want anything about s3 credentials here?

optional_checks = %w[external-workflow-services-url]
optional_checks << 'feature-zip_storage_dir' if worker_host?
OkComputer.make_optional optional_checks
