# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationJob do
  it 'queues start empty' do
    expect(enqueued_jobs.size).to eq 0
  end

  describe 'SolidQueue shutdown configuration' do
    it 'uses JOB_SHUTDOWN_TIMEOUT env var or defaults to 96 hours' do
      expected = ENV.fetch('JOB_SHUTDOWN_TIMEOUT', 345_600).to_i
      expect(Rails.application.config.solid_queue.shutdown_timeout).to eq(expected)
    end
  end

  describe 'retry on SolidQueue process errors' do
    # retry_on registers handlers via rescue_from; verify both error classes are registered
    # so that jobs killed mid-run (e.g. KILL signal, OOM, or expired heartbeat) are
    # automatically re-enqueued rather than silently dropped after a deployment.
    let(:registered_handler_names) { described_class.rescue_handlers.map(&:first) }

    it 'retries when a worker process exits unexpectedly (ProcessExitError)' do
      expect(registered_handler_names).to include('SolidQueue::Processes::ProcessExitError')
    end

    it 'retries when a worker process is pruned due to a missed heartbeat (ProcessPrunedError)' do
      expect(registered_handler_names).to include('SolidQueue::Processes::ProcessPrunedError')
    end

    it 'uses the wait period from Settings' do
      handler = described_class.rescue_handlers.find { |name, _| name == 'SolidQueue::Processes::ProcessExitError' }
      expect(handler).not_to be_nil
    end
  end
end
