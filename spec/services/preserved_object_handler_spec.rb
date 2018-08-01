require 'rails_helper'
require 'services/shared_examples_preserved_object_handler'

RSpec.describe PreservedObjectHandler do
  before do
    allow(Dor::WorkflowService).to receive(:update_workflow_error_status)
  end

  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let!(:default_prez_policy) { PreservationPolicy.default_policy }
  let(:po) { PreservedObject.find_by(druid: druid) }
  let(:ms_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  let(:cm) { CompleteMoab.find_by(preserved_object: po, moab_storage_root: ms_root) }
  let(:po_handler) { described_class.new(druid, incoming_version, incoming_size, ms_root) }

  describe '#initialize' do
    it 'sets druid' do
      po_handler = described_class.new(druid, incoming_version, nil, ms_root)
      expect(po_handler.druid).to eq druid
    end
    context 'sets incoming_version' do
      { # passed value => expected parsed value
        6 => 6,
        0 => 0,
        -1 => -1,
        '6' => 6,
        '006' => 6,
        'v0006' => 6,
        '0' => 0,
        '-666' => '-666',
        'vv001' => 'vv001',
        'asdf' => 'asdf'
      }.each do |k, v|
        it "by parsing '#{k}' to '#{v}'" do
          po_handler = described_class.new(druid, k, nil, ms_root)
          expect(po_handler.incoming_version).to eq v
        end
      end
    end

    context 'sets incoming_size' do
      { # passed value => expected parsed value
        6 => 6,
        0 => 0,
        -1 => -1,
        '0' => 0,
        '6' => 6,
        '006' => 6,
        'v0006' => 'v0006',
        '-666' => '-666',
        'vv001' => 'vv001',
        'asdf' => 'asdf'
      }.each do |k, v|
        it "by parsing '#{k}' to '#{v}'" do
          po_handler = described_class.new(druid, nil, k, ms_root)
          expect(po_handler.incoming_size).to eq v
        end
      end
    end

    it 'exposes storage_location (from MoabStorageRoot)' do
      po_handler = described_class.new(druid, incoming_version, nil, ms_root)
      expect(po_handler.storage_location).to eq ms_root.storage_location
    end
    it 'sets MoabStorageRoot' do
      po_handler = described_class.new(druid, incoming_version, nil, ms_root)
      expect(po_handler.moab_storage_root).to eq ms_root
    end
  end

  describe '#with_active_record_transaction_and_rescue' do
    it '#confirm_version rolls back preserved object if there is a problem updating complete moab' do
      po = PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
      cm = CompleteMoab.create!(
        preserved_object: po,
        version: po.current_version,
        size: 1,
        moab_storage_root: ms_root,
        status: 'validity_unknown'
      )
      bad_po_handler = described_class.new(druid, 6, incoming_size, ms_root)
      allow(cm).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError)
      allow(bad_po_handler).to receive(:moab_validation_errors).and_return([])
      bad_po_handler.confirm_version
      expect(PreservedObject.find_by(druid: druid).current_version).to eq 2
    end

    context 'ActiveRecordError gives DB_UPDATE_FAILED error with rich details' do
      let(:result_code) { AuditResults::DB_UPDATE_FAILED }
      let(:results) do
        allow(PreservedObject).to receive(:create!).with(hash_including(druid: druid))
                                                   .and_raise(ActiveRecord::ActiveRecordError, 'specific_err_msg')
        po_handler.create
      end

      it 'specific exception raised' do
        expect(results).to include(a_hash_including(result_code => a_string_matching('ActiveRecord::ActiveRecordError')))
      end
      it "exception's message" do
        expect(results).to include(a_hash_including(result_code => a_string_matching('specific_err_msg')))
      end
    end
  end

  describe '#moab_validation_errors' do
    it 'calls validator.validator_errors with moab.allow_content_subdirs from Settings.yml' do
      sov = instance_double(Moab::StorageObjectValidator)
      allow(Moab::StorageObjectValidator).to receive(:new).and_return(sov)
      expect(sov).to receive(:validation_errors).with(true).and_return([])
      po_handler.create_after_validation
    end
  end

  describe 'MoabStorageRoot validation' do
    it 'errors when moab_storage_root is not an MoabStorageRoot object' do
      poh = described_class.new(druid, incoming_version, incoming_size, 1)
      expect(poh).to be_invalid
      expect(poh.errors.messages).to include(moab_storage_root: ["must be an actual MoabStorageRoot"])
    end
  end
end
