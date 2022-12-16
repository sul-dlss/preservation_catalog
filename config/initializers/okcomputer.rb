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

# check MoabRecord#last_version_audit to ensure it isn't too old
class VersionAuditWindowCheck < OkComputer::Check
  def check
    if MoabRecord.version_audit_expired(clause).first
      mark_message "MoabRecord#last_version_audit older than #{clause}. "
      mark_failure
    else
      mark_message "MoabRecord#last_version_audit all newer than #{clause}. "
    end
  end

  private def clause
    # currently: M2C and C2M are queued on the 1st and 15th of the month, respectively, and
    # expiry time on CV is 3 months (those are the three audits that touch this timestamp).
    # M2C should run at most 16 days after C2M (following a 31 day month), but give a little buffer
    # since the queues might take a while to work down, and ordering for enqueue is uncertain.
    21.days.ago
  end
end
OkComputer::Registry.register 'feature-version-audit-window-check', VersionAuditWindowCheck.new

# TODO: do we want anything about s3 credentials here?

optional_checks = %w[feature-version-audit-window-check external-workflow-services-url]
optional_checks << 'feature-zip_storage_dir' if worker_host?
OkComputer.make_optional optional_checks
