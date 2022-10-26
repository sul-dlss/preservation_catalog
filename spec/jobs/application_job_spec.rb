# frozen_string_literal: true

require 'rails_helper'

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

RSpec.describe ApplicationJob do
  include ActiveJob::TestHelper

  around do |example|
    old_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :resque
    example.run
    ActiveJob::Base.queue_adapter = old_adapter
  end

  it 'queues start empty' do
    expect(enqueued_jobs.size).to eq 0
  end

  context 'a subclass with message(s) queued' do
    it 'does not add duplicate messages' do
      RegularParameterJob.perform_later('1234abc', 1, false)
      expect { RegularParameterJob.perform_later('1234abc', 1, false) }
        .not_to change(enqueued_jobs, :size).from(1)
    end

    it 'but adds novel messages' do
      RegularParameterJob.perform_later('1234abc', 1, false)
      expect { RegularParameterJob.perform_later('7890xyz', 1, false) } # different druid
        .to change(enqueued_jobs, :size).from(1).to(2)
      expect { RegularParameterJob.perform_later('1234abc', 2, false) } # same druid, different version
        .to change(enqueued_jobs, :size).from(2).to(3)
    end

    it 'cleans up its lock after succeeding so that the same job with the same params can be queued again immediately' do
      RegularParameterJob.perform_later('4321cba', 1, false)

      perform_enqueued_jobs

      expect { RegularParameterJob.perform_later('4321cba', 1, false) }
        .to change(enqueued_jobs, :size).from(0).to(1)
    end

    it 'cleans up its lock after failing so that the same job with the same params can be queued again immediately' do
      RegularParameterJob.perform_later('0987zyx', 1, true)

      begin
        perform_enqueued_jobs
      rescue StandardError
        # In the app code we wouldn't deal with errors directly when a job raises, because the
        # workers are picking them up and running them async (and then the adapter, Resque,
        # does the appropriate error handling, e.g. moves the job to the appropriate failure queue, etc)
      end

      expect { RegularParameterJob.perform_later('0987zyx', 1, true) }
        .to change(enqueued_jobs, :size).from(0).to(1)
    end

    it 'enqueues the job if it detects an existing lock that has expired' do
      RegularParameterJob.perform_later('4321cba', 1, false)

      sleep(RegularParameterJob.lock_timeout + 3) # lock timeout is very short, this should go well past it

      expect { RegularParameterJob.perform_later('4321cba', 1, false) }
        .to change(enqueued_jobs, :size).from(1).to(2)
    end
  end

  context 'a subclass that has an ActiveRecord parameter with message(s) queued' do
    let(:cm) { create(:complete_moab) }
    let(:cm2) { create(:complete_moab) }

    before do
      CatalogToMoabJob.perform_later(cm)
    end

    it 'does not add duplicate messages' do
      expect { CatalogToMoabJob.perform_later(cm) }
        .not_to change(enqueued_jobs, :size).from(1)

      # Change complete_moab
      cm.size = 1000

      expect { CatalogToMoabJob.perform_later(cm) }
        .not_to change(enqueued_jobs, :size).from(1)
    end

    it 'but adds novel messages' do
      expect { CatalogToMoabJob.perform_later(cm2) }
        .to change(enqueued_jobs, :size).from(1).to(2)
    end
  end
end
