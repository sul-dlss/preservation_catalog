# frozen_string_literal: true

require 'okcomputer'
require Rails.root.join('config', 'initializers', 'resque.rb').to_s

OkComputer.mount_at = 'status' # use /status or /status/all or /status/<name-of-check>
OkComputer.check_in_parallel = true

# check models to see if at least they have some data
class TablesHaveDataCheck < OkComputer::Check
  def check
    msg = [
      MoabStorageRoot,
      PreservationPolicy
    ].map { |klass| table_check(klass) }.join(' ')
    mark_message msg
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
OkComputer::Registry.register "feature-tables-have-data", TablesHaveDataCheck.new

# check that directory is accessible without consideration for writability
class DirectoryExistsCheck < OkComputer::Check
  attr_accessor :directory

  def initialize(directory)
    self.directory = directory
  end

  def check
    stat = File.stat(directory) if File.exist?(directory)
    if stat
      if stat.directory?
        mark_message "'#{directory}' is a reachable directory"
      else
        mark_message "'#{directory}' is not a directory."
        mark_failure
      end
    else
      mark_message "Directory '#{directory}' does not exist."
      mark_failure
    end
  end
end
Settings.storage_root_map.default.each do |name, location|
  OkComputer::Registry.register "feature-#{name}", DirectoryExistsCheck.new(location)
end

OkComputer::Registry.register 'ruby_version', OkComputer::RubyVersionCheck.new

# check whether resque workers are working
OkComputer::Registry.register 'feature-resque-down', OkComputer::ResqueDownCheck.new

# check for backed up resque queues
Resque.queues.each do |queue|
  OkComputer::Registry.register "feature-#{queue}-queue-depth",
                                OkComputer::ResqueBackedUpCheck.new(queue, 5_000_000)
end

# check for failed resque jobs
Resque::Failure.queues.each do |queue|
  OkComputer::Registry.register "feature-#{queue}-queue-threshold",
                                OkComputer::SizeThresholdCheck.new(queue, 20) { Resque::Failure.count(queue) }
end

# check for the right number of workers
class WorkerCountCheck < OkComputer::Check
  def check
    count = Settings.total_worker_count
    if Resque.workers.count == count
      mark_message "#{count} workers are up."
    else
      mark_failure
      mark_message "Not all #{count} workers are up!"
    end
  end
  OkComputer::Registry.register 'feature-worker-count', WorkerCountCheck.new
end

# ------------------------------------------------------------------------------

# NON-CRUCIAL (Optional) checks, avail at /status/<name-of-check>
#   - at individual moab_storage_root, HTTP response code reflects the actual result
#   - in /status/all, these checks will display their result text, but will not affect HTTP response code

# Audit Checks (only) report errors to workflow service so they appear in Argo
workflows_url = "#{Settings.workflow_services_url}/objects/druid:oo000oo0000/workflows"
OkComputer::Registry.register "external-workflow-services-url", OkComputer::HttpCheck.new(workflows_url)

# Replication (only) uses zip_storage directory to build the zips to send to zip endpoints
OkComputer::Registry.register "feature-zip_storage_dir", OkComputer::DirectoryCheck.new(Settings.zip_storage)

# check CompleteMoab#last_version_audit to ensure it isn't too old
class VersionAuditWindowCheck < OkComputer::Check
  def check
    if CompleteMoab.least_recent_version_audit(clause).first
      mark_message "CompleteMoab\#last_version_audit older than #{clause}. "
      mark_failure
    else
      mark_message "CompleteMoab\#last_version_audit all newer than #{clause}. "
    end
  end

  private def clause
    14.days.ago
  end
end
OkComputer::Registry.register "feature-version-audit-window-check", VersionAuditWindowCheck.new

# TODO: do we want anything about s3 credentials here?

OkComputer.make_optional %w[feature-version-audit-window-check external-workflow-services-url feature-zip_storage_dir]
