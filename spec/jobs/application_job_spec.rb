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
    let(:cm) { create :complete_moab }

    before do
      allow(CatalogToMoabJob).to receive(:perform_later).and_call_original # undo rails_helper block
      CatalogToMoabJob.perform_later(cm, 'foo')
    end

    it 'does not add duplicate messages' do
      expect { CatalogToMoabJob.perform_later(cm, 'foo') }
        .not_to change { Resque.info[:pending] }.from(1)

      # Change complete_moab
      cm.size = 1000

      expect { CatalogToMoabJob.perform_later(cm, 'foo') }
        .not_to change { Resque.info[:pending] }.from(1)
    end

    it 'but adds novel messages' do
      expect { CatalogToMoabJob.perform_later(cm, 'bar') }
        .to change { Resque.info[:pending] }.from(1).to(2)
    end
  end
end
