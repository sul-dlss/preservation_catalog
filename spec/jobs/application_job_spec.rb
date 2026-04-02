# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApplicationJob do
  it 'queues start empty' do
    expect(enqueued_jobs.size).to eq 0
  end
end
