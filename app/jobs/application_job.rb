require 'resque/plugins/lock'

# Base job for this Application
# @note We do queue locking via 2 methods from resque-lock in callbacks.
# We abort on lock collision, preventing duplicate Jobs from enqueuing.
# The key is specified by a 3rd `lock` method, by default based on job name and
# serialized arguments (which works well for druid/version), but can be overridden
# per job class, if needed.  Locks are stored in Redis w/ TTL date integers.
# @see [resque-lock] https://github.com/defunkt/resque-lock/blob/master/lib/resque/plugins/lock.rb
# @see [redis setnx] http://redis.io/commands/setnx
class ApplicationJob < ActiveJob::Base
  extend Resque::Plugins::Lock

  before_perform do |_job|
    ActiveRecord::Base.clear_active_connections!
  end

  before_enqueue do |job|
    throw(:abort) unless job.class.before_enqueue_lock(*job.arguments)
  end
  around_perform do |job, block|
    job.class.around_perform_lock(*job.arguments, &block)
  end

  # Override in subclass to tune per queue.
  # def lock_timeout
  #   3600
  # end

  # Automatically retry jobs that encountered a deadlock
  # retry_on ActiveRecord::Deadlocked
  # Most jobs are safe to ignore if the underlying records are no longer available
  # discard_on ActiveJob::DeserializationError

  # Raises if the metadata is incomplete
  # @param [Hash<Symbol => String>] metadata
  # @option metadata [String] :checksum_md5
  # @option metadata [String] :size
  # @option metadata [String] :zip_cmd
  # @option metadata [String] :zip_version
  def zip_info_check!(metadata)
    raise ArgumentError, 'metadata Hash not found' if metadata.blank?
    %i[checksum_md5 size zip_cmd zip_version].each do |key|
      raise ArgumentError, "Required metadata[:#{key}] not found" if metadata[key].blank?
    end
  end
end
