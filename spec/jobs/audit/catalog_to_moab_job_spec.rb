# frozen_string_literal: true

require 'rails_helper'

describe Audit::CatalogToMoabJob do
  let(:job) { described_class.new(moab_record) }
  let(:moab_record) { create(:moab_record) }

  describe '#perform' do
    let(:validator) { instance_double(Audit::CatalogToMoab) }

    before do
      allow(validator).to receive(:check_catalog_version)
      allow(Audit::CatalogToMoab).to receive(:new).with(moab_record).and_return(validator)
    end

    it 'calls Audit::CatalogToMoab#check_catalog_version' do
      job.perform(moab_record)
      expect(validator).to have_received(:check_catalog_version)
    end
  end
end
