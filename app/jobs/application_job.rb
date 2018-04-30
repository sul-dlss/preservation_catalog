# Auto-generated base job, for our amendment
class ApplicationJob < ActiveJob::Base
  before_perform do |_job|
    ActiveRecord::Base.clear_active_connections!
  end

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked
  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError
end
