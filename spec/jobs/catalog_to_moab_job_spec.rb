# frozen_string_literal: true

require 'rails_helper'

describe CatalogToMoabJob, type: :job do
  let(:job) { described_class.new(cm) }
  let(:cm) { create :complete_moab }

  describe '#perform' do
    let(:validator) { instance_double(Audit::CatalogToMoab) }

    it 'calls Audit::CatalogToMoab#check_catalog_version' do
      expect(validator).to receive(:check_catalog_version)
      expect(Audit::CatalogToMoab).to receive(:new).with(cm).and_return(validator)
      job.perform(cm)
    end

    context 'there are two moabs for the druid' do
      let(:druid) { 'bz514sm9647' }
      let(:msr_1) { MoabStorageRoot.find_by!(name: 'fixture_sr1') }
      let(:msr_a) { MoabStorageRoot.find_by!(name: 'fixture_srA') }
      let(:po) { create(:preserved_object, druid: druid, current_version: 1) }
      let(:cm_1) { create(:complete_moab, preserved_object: po, version: 1, moab_storage_root: msr_1) } # this catalog entry lags disk to start test
      let(:cm_a) { create(:complete_moab, preserved_object: po, version: 1, moab_storage_root: msr_a) }

      context 'the one with the lower version is the primary' do
        before do
          PreservedObjectsPrimaryMoab.create!(preserved_object: po, complete_moab: cm_1) # version that's ahead, on 01, is primary
          job.perform(cm_1)
          job.perform(cm_a)
        end

        it 'sets CompleteMoab#version to the version of the moab on that storage root' do
          expect(cm_1.reload.version).to eq 3
          expect(cm_a.reload.version).to eq 1
        end

        it 'sets PreservedObject#current_version to the highest version seen for the primary CompleteMoab' do
          expect(po.reload.current_version).to eq 3
        end
      end

      context 'the one with the higher version is the primary' do
        before do
          PreservedObjectsPrimaryMoab.create!(preserved_object: po, complete_moab: cm_a) # version that's behind, on A, is primary
          job.perform(cm_a)
          job.perform(cm_1)
        end

        it 'sets CompleteMoab#version to the version of the moab on that storage root' do
          expect(cm_1.reload.version).to eq 3
          expect(cm_a.reload.version).to eq 1
        end

        it 'sets PreservedObject#current_version to the highest version seen for the primary CompleteMoab' do
          expect(po.reload.current_version).to eq 1 # the copy that's behind is the primary -- this would be unusual, but just to define the behavior
        end
      end
    end
  end
end
