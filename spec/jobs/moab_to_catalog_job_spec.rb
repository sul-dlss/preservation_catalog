# frozen_string_literal: true

require 'rails_helper'

describe MoabToCatalogJob, type: :job do
  let(:job) { described_class.new(msr, druid, path) }
  let(:msr) { create :moab_storage_root }
  let(:druid) { 'bj102hs9687' }
  let(:path) { "#{msr.storage_location}/bj/102/hs/9687/bj102hs9687" }
  let(:moab) { instance_double(Moab::StorageObject, size: 22, current_version_id: 3) }

  describe '#perform' do
    let(:handler) { instance_double(CompleteMoabHandler) }

    it 'builds a CompleteMoabHandler and calls #check_existence' do
      expect(Moab::StorageObject).to receive(:new).with(druid, path).and_return(moab)
      expect(CompleteMoabHandler).to receive(:new)
        .with(druid, moab.current_version_id, moab.size, msr).and_return(handler)
      expect(handler).to receive(:check_existence)
      job.perform(msr, druid)
    end
  end

  context 'there are two moabs for the druid' do
    let(:druid) { 'bz514sm9647' }
    let(:msr_1) { MoabStorageRoot.find_by!(name: 'fixture_sr1') }
    let(:msr_a) { MoabStorageRoot.find_by!(name: 'fixture_srA') }
    let(:cm_1) { CompleteMoab.by_druid(druid).find_by!(moab_storage_root: msr_1) }
    let(:cm_a) { CompleteMoab.by_druid(druid).find_by!(moab_storage_root: msr_a) }
    let(:po) { PreservedObject.find_by!(druid: druid) }

    context 'the one with the lower version is the primary' do
      before do
        job.perform(msr_1, druid) # first added is primary by default
        job.perform(msr_a, druid)
      end

      it 'sets CompleteMoab#version to the version of the moab on that storage root' do
        expect(cm_1.version).to eq 3
        expect(cm_a.version).to eq 1
      end

      it 'sets PreservedObject#current_version to the highest version seen for the primary CompleteMoab' do
        expect(po.current_version).to eq 3
      end
    end

    context 'the one with the higher version is the primary' do
      before do
        job.perform(msr_a, druid) # first added is primary by default
        job.perform(msr_1, druid)
      end

      it 'sets CompleteMoab#version to the version of the moab on that storage root' do
        expect(cm_1.version).to eq 3
        expect(cm_a.version).to eq 1
      end

      it 'sets PreservedObject#current_version to the highest version seen for the primary CompleteMoab' do
        expect(po.current_version).to eq 1 # the copy that's behind is the primary -- this would be unusual, but just to define the behavior
      end
    end
  end
end
