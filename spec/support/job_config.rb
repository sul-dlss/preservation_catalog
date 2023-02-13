# frozen_string_literal: true

RSpec.configure do |config|
  config.before do
    next unless RSpec.current_example.metadata[:type] == :job

    ActiveJob::Base.queue_adapter = :test
    allow(ActiveJob::Base.logger).to receive(:info) # keep the default logging quiet

    begin
      Sidekiq.redis(&:flushall) # clear queues and locks
    rescue Redis::CannotConnectError
      p 'we are rescuing!' # rubocop:disable Lint/Debugger
    end
  end
end
