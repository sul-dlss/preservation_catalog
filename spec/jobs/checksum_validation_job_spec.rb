# frozen_string_literal: true

require 'rails_helper'

describe ChecksumValidationJob do
  let(:job) { described_class.new(cm) }
  let(:cm) { create(:complete_moab) }

  describe '#perform' do
    let(:validator) { instance_double(Audit::ChecksumValidator) }

    it 'calls ChecksumValidator#validate_checksums' do
      expect(validator).to receive(:validate_checksums)
      expect(Audit::ChecksumValidator).to receive(:new).with(cm).and_return(validator)
      job.perform(cm)
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
      described_class.queue_adapter = :resque
      example.run
      described_class.queue_adapter = old_adapter
    end

    before { allow(described_class).to receive(:perform_later).and_call_original } # undo rails_helper block

    it 'does not add duplicate messages' do
      described_class.perform_later(cm)
      expect { described_class.perform_later(cm) }
        .not_to change { Resque.info[:pending] }.from(1)
    end
  end
end
