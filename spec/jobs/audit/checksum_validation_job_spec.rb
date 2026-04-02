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
end
