# frozen_string_literal: true

require 'rails_helper'

describe CatalogToMoabJob do
  let(:job) { described_class.new(cm) }
  let(:cm) { create(:complete_moab) }

  describe '#perform' do
    let(:validator) { instance_double(Audit::CatalogToMoab) }

    it 'calls Audit::CatalogToMoab#check_catalog_version' do
      expect(validator).to receive(:check_catalog_version)
      expect(Audit::CatalogToMoab).to receive(:new).with(cm).and_return(validator)
      job.perform(cm)
    end
  end
end
