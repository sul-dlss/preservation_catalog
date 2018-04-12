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
OkComputer::Registry.register "version-audit-window-check", VersionAuditWindowCheck.new
