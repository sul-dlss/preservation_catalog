# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationJob do
  it 'queues start empty' do
    expect(enqueued_jobs.size).to eq 0
  end

  describe 'SolidQueue shutdown configuration' do
    it 'allows long-running jobs to finish before workers are killed on deployment' do
      expect(Rails.application.config.solid_queue.shutdown_timeout).to eq(86_400)
    end
  end
end
