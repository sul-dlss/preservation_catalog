# frozen_string_literal: true

# Q: Why copy the logic out of resque-lock instead of using the gem?
# A: It's a small amount of (MIT licensed) code, the gem is and unmaintained (last updated in 2012),
# and the lock cleanup hook wasn't getting invoked automatically in our jobs.  Inlining the code
# reduces indirection and dependency (on both resque-lock and on Resque itself, since we use ActiveJob
# hooks here instead of Resque hooks).

# @note logic for `before_enqueue` `around_perform`/`clear_lock`, `queue_lock_key`, `before_enqueue_lock`, and
#   `lock_timeout` from resque-lock.
# @see [resque-lock] https://github.com/defunkt/resque-lock/blob/e06fc2bd26f96f4f3fe893caa49c1cd42c0c9423/lib/resque/plugins/lock.rb
#
# Copyright (c) Chris Wanstrath, Ray Krueger
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# Software), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED AS IS, WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# https://github.com/defunkt/resque-lock/blob/e06fc2bd26f96f4f3fe893caa49c1cd42c0c9423/LICENSE
#
# This additional copyright statement applies solely to the code that was taken from resque-lock.

# @note We abort on lock collision, preventing duplicate Jobs from enqueuing.
#   The key is specified by the `queue_lock_key` class method, by default based on job name
#   and serialized arguments (which works well for druid/version), but can be overridden
#   per job class, if needed.  Locks are stored in Redis w/ expiry dates as integers.
# @see [redis setnx] https://redis.io/commands/setnx (explains the reasoning behind the pattern)
# @note Job uniqueness is useful because it usually doesn't make sense in this app for more than one instance
#   of the same job to be enqueued at a time. E.g. it'd be unnecessary to queue more than one checksum validation
#   job at once for the same druid; it'd be unnecessary to queue two instances of ZipmakerJob for the same Moab version;
#   and we wouldn't want to attempt multiple deliveries of the same zipped Moab version to a given cloud endpoint. Jobs
#   generally check that the file they're trying to write or push doesn't yet exist, but the check and write
#   in combination won't be transactional if via file system or REST call, so this provides some extra safeguard
#   against such race conditions. It also gives a bit of extra safety around refactoring job invocations.
module UniqueJob
  extend ActiveSupport::Concern

  included do
    before_enqueue do |job|
      throw(:abort) unless job.class.before_enqueue_lock(*job.arguments)
    end

    around_perform do |job, block|
      block.call
    ensure
      # Always clear the lock when we're done, even if there was an error.
      job.class.clear_lock(*job.arguments)
    end
  end

  class_methods do # rubocop:disable Metrics/BlockLength
    # Override in subclass to tune per queue.
    # @return [Integer] lock_timeout in seconds, after which lock is no longer valid,
    # regardless of whether the job that created the lock is still in queue or working.
    def lock_timeout
      # 1 hour is a reasonable default, because most jobs in this app will
      # cause only minor trouble if re-executed too aggressively.
      3600
    end

    def redis_connection
      # when we switch to sidekiq we can call `Sidekiq.redis(&block)`
      yield Resque.redis
    end

    # @return [String] the key for locking this job/payload combination, e.g. 'lock:MySpecificJob-bt821jk7040;1'
    def queue_lock_key(*args)
      # Changes in ActiveModel object don't result in new lock (which they do when just calling to_s).
      queue_lock_args = args.map { |arg| arg.class.method_defined?(:to_global_id) ? arg.to_global_id.to_s : arg }
      "lock:#{name}-#{queue_lock_args.join(';')}"
    end

    def before_enqueue_lock(*args)
      key = queue_lock_key(*args)
      now = Time.now.to_i
      new_expiry_time = now + lock_timeout + 1

      redis_connection do |conn|
        # return true if we successfully acquired the lock
        # "Set key to hold string value if key does not exist" (otherwise no-op) -- https://redis.io/commands/setnx
        if conn.setnx(key, new_expiry_time)
          Rails.logger.info("acquired lock on #{key} (none existed)")
          return true
        end

        # see if the existing lock is still valid and return false if it is
        # (we cannot acquire the lock during the timeout period)
        key_expires_at = conn.get(key).to_i
        if now <= key_expires_at
          Rails.logger.info("failed to acquire lock on #{key}, because it has not expired (#{now} <= #{key_expires_at})")
          return false
        end

        # otherwise set the new_expiry_time and ensure that no other worker has
        # acquired the lock, possibly pushing out the expiry time further
        # "Atomically sets key to value and returns the old value stored at key." -- https://redis.io/commands/getset
        key_expires_at = conn.getset(key, new_expiry_time).to_i
        if now > key_expires_at
          Rails.logger.info("acquired lock on #{key} (old lock expired, #{now} > #{key_expires_at})")
          true
        else
          Rails.logger.info("failed to acquire lock on #{key} but updated expiry time to #{new_expiry_time} (#{now} <= #{key_expires_at})")
          false
        end
      end
    end

    def clear_lock(*args)
      key = queue_lock_key(*args)
      Rails.logger.info("clearing lock for #{key}...")
      redis_connection do |conn|
        conn.del(key).tap do |del_result|
          Rails.logger.info("...cleared lock for #{key} (del_result=#{del_result})")
        end
      end
    end
  end
end
