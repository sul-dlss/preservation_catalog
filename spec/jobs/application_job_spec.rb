# frozen_string_literal: true

require 'rails_helper'

describe ApplicationJob, type: :job do
  around do |example|
    old_adapter = described_class.queue_adapter
    described_class.queue_adapter = :resque
    example.run
    described_class.queue_adapter = old_adapter
  end

  it 'queues start empty' do
    expect(Resque.info).to include(pending: 0)
  end

  context 'a subclass with message(s) queued' do
    before do
      allow(ZipmakerJob).to receive(:perform_later).and_call_original # undo rails_helper block
      ZipmakerJob.perform_later('1234abc', 1)
    end

    it 'does not add duplicate messages' do
      expect { ZipmakerJob.perform_later('1234abc', 1) }
        .not_to change { Resque.info[:pending] }.from(1)
    end

    it 'but adds novel messages' do
      expect { ZipmakerJob.perform_later('7890xyz', 1) } # different druid
        .to change { Resque.info[:pending] }.from(1).to(2)
      expect { ZipmakerJob.perform_later('1234abc', 2) } # same druid, different version
        .to change { Resque.info[:pending] }.from(2).to(3)
    end
  end
end
