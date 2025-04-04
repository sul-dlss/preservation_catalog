# frozen_string_literal: true

require 'rails_helper'

describe Audit::ChecksumValidationJob do
  let(:job) { described_class.new(moab_record) }
  let(:moab_record) { create(:moab_record) }

  describe '#perform' do
    let(:validator) { instance_double(Audit::ChecksumValidationService) }

    before do
      allow(Audit::ChecksumValidationService).to receive(:new).with(moab_record).and_return(validator)
      allow(validator).to receive(:validate_checksums)
    end

    it 'calls ChecksumValidationService#validate_checksums' do
      job.perform(moab_record)
      expect(validator).to have_received(:validate_checksums)
    end
  end

  describe 'before_enqueue' do
    before { allow(described_class).to receive(:perform_later).and_call_original } # undo rails_helper block

    it 'raises on bad param' do
      expect { described_class.perform_later(3) }.to raise_error(ArgumentError)
      expect { described_class.perform_later }.to raise_error(ArgumentError)
    end
  end

  context 'a subclass with message(s) queued' do
    around do |example|
      old_adapter = described_class.queue_adapter
      described_class.queue_adapter = :sidekiq
      example.run
      described_class.queue_adapter = old_adapter
    end

    let(:stats) { Sidekiq::Stats.new }

    before { allow(described_class).to receive(:perform_later).and_call_original } # undo rails_helper block

    it 'does not add duplicate messages' do
      described_class.perform_later(moab_record)
      expect { described_class.perform_later(moab_record) }
        .not_to change(stats, :enqueued).from(1)
    end
  end
end
