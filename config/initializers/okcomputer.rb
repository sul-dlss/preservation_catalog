require 'okcomputer'

OkComputer.mount_at = 'status' # use /status or /status/all or /status/<name-of-check>
OkComputer.check_in_parallel = true

# check models to see if at least they have some data
class TablesHaveDataCheck < OkComputer::Check
  def check
    msg = [
      Endpoint,
      PreservationPolicy
    ].map { |klass| table_check(klass) }.join(' ')
    mark_message msg
  end

  # @return [String] message
  private def table_check(klass)
    # has at least 1 record, using select(:id) to avoid returning all data
    return "#{klass.name} has data." if klass.select(:id).first!.present?
    mark_failure
    "#{klass.name} has no data."
  rescue ActiveRecord::RecordNotFound
    mark_failure
    "#{klass.name} has no data."
  rescue => e # rubocop:disable Lint/RescueWithoutErrorClass
    mark_failure
    "#{e.class.name} received: #{e.message}."
  end
end
OkComputer::Registry.register "feature-tables-have-data", TablesHaveDataCheck.new

HostSettings.storage_roots.each do |storage_root_name_val|
  OkComputer::Registry.register "feature-#{storage_root_name_val.first}",
                                OkComputer::DirectoryCheck.new(storage_root_name_val.last)
end

# want anything about s3 credentials here?

# workflow_services_url - for reporting auditing errors
# zip_storage

OkComputer::Registry.register 'ruby_version', OkComputer::RubyVersionCheck.new

# ------------------------------------------------------------------------------

# NON-CRUCIAL (Optional) checks, avail at /status/<name-of-check>
#   - at individual endpoint, HTTP response code reflects the actual result
#   - in /status/all, these checks will display their result text, but will not affect HTTP response code

# check PreservedCopy#last_version_audit to ensure it isn't too old
class VersionAuditWindowCheck < OkComputer::Check
  def check
    if PreservedCopy.least_recent_version_audit(clause).first
      mark_message "PreservedCopy\#last_version_audit older than #{clause}. "
      mark_failure
    else
      mark_message "PreservedCopy\#last_version_audit all newer than #{clause}. "
    end
  end

  private def clause
    14.days.ago
  end
end
OkComputer::Registry.register "feature-version-audit-window-check", VersionAuditWindowCheck.new

OkComputer.make_optional %w[feature-version-audit-window-check]
