# frozen_string_literal: true

require 'rails_helper'

describe MoabToCatalogJob, type: :job do
  let(:job) { described_class.new(msr, druid, path) }
  let(:msr) { create :moab_storage_root }
  let(:druid) { 'bj102hs9687' }
  let(:path) { 'foobar' }
  let(:moab) { instance_double(Moab::StorageObject, size: 22, current_version_id: 3) }

  describe '#perform' do
    let(:handler) { instance_double(PreservedObjectHandler) }

    it 'builds a PreservedObjectHandler and calls #check_existence' do
      expect(Moab::StorageObject).to receive(:new).with(druid, path).and_return(moab)
      expect(PreservedObjectHandler).to receive(:new)
        .with(druid, moab.current_version_id, moab.size, msr).and_return(handler)
      expect(handler).to receive(:check_existence)
      job.perform(msr, druid, path)
    end
  end

  describe '#perform without path' do
    let(:msr) { create :moab_storage_root }
    let(:path) { "#{msr.storage_location}/bj/102/hs/9687/bj102hs9687" }
    let(:handler) { instance_double(PreservedObjectHandler) }

    it 'builds a PreservedObjectHandler from MoabStorageRoot and druid if path is missing' do
      expect(Moab::StorageObject).to receive(:new).with(druid, path).and_return(moab)
      expect(PreservedObjectHandler).to receive(:new)
        .with(druid, moab.current_version_id, moab.size, msr).and_return(handler)
      expect(handler).to receive(:check_existence)
      job.perform(msr, druid)
    end
  end
end
