# frozen_string_literal: true

# A very simple job class that extends ApplicationJob to allow testing of basic queue locking behavior
class RegularParameterJob < ApplicationJob
  include UniqueJob
  def self.lock_timeout
    1
  end

  def perform(param_a, param_b, should_raise)
    Rails.logger.info("simulate a running job to better test queue locking: (#{param_a}, #{param_b}, #{should_raise})")

    raise 'oops' if should_raise
  end
end
