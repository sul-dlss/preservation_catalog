# frozen_string_literal: true

require 'rails_helper'

describe Audit::MoabToCatalogJob do
  let(:job) { described_class.new(msr, druid, path) }
  let(:msr) { create(:moab_storage_root) }
  let(:druid) { 'bj102hs9687' }
  let(:path) { "#{msr.storage_location}/bj/102/hs/9687/bj102hs9687" }
  let(:moab) { instance_double(Moab::StorageObject, size: 22, current_version_id: 3) }

  describe '#perform' do
    before do
      allow(Moab::StorageObject).to receive(:new).with(druid, path).and_return(moab)
      allow(MoabRecordService::CheckExistence).to receive(:execute)
    end

    it 'checks existence' do
      job.perform(msr, druid)
      expect(MoabRecordService::CheckExistence).to have_received(:execute).with(druid: druid,
                                                                                incoming_version: moab.current_version_id,
                                                                                incoming_size: moab.size,
                                                                                moab_storage_root: msr)
    end
  end
end
