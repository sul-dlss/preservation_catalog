# frozen_string_literal: true

require 'rails_helper'

describe CatalogToMoabJob do
  let(:job) { described_class.new(moab_record) }
  let(:moab_record) { create(:moab_record) }

  describe '#perform' do
    let(:validator) { instance_double(Audit::CatalogToMoab) }

    it 'calls Audit::CatalogToMoab#check_catalog_version' do
      expect(validator).to receive(:check_catalog_version)
      expect(Audit::CatalogToMoab).to receive(:new).with(moab_record).and_return(validator)
      job.perform(moab_record)
    end
  end
end
