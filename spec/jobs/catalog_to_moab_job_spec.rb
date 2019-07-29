# frozen_string_literal: true

require 'rails_helper'

describe CatalogToMoabJob, type: :job do
  let(:job) { described_class.new(cm) }
  let(:cm) { create :complete_moab }
  let(:storage_dir) { 'foobar' }

  describe '#perform' do
    let(:validator) { instance_double(Audit::CatalogToMoab) }

    it 'calls Audit::CatalogToMoab#check_catalog_version' do
      expect(validator).to receive(:check_catalog_version)
      expect(Audit::CatalogToMoab).to receive(:new).with(cm, storage_dir).and_return(validator)
      job.perform(cm, storage_dir)
    end
  end
end
