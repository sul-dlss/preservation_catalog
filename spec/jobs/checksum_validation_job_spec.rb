require 'rails_helper'

describe ChecksumValidationJob, type: :job do
  let(:job) { described_class.new(pc) }
  let(:pc) { create :complete_moab }

  describe '#perform' do
    let(:validator) { instance_double(ChecksumValidator) }

    it 'calls ChecksumValidator#validate_checksums' do
      expect(validator).to receive(:validate_checksums)
      expect(ChecksumValidator).to receive(:new).with(pc).and_return(validator)
      job.perform(pc)
    end
  end

  describe 'before_enqueue' do
    it 'raises on bad param' do
      expect { described_class.perform_later(3) }.to raise_error(ArgumentError)
      expect { described_class.perform_later }.to raise_error(ArgumentError)
    end
  end
end
