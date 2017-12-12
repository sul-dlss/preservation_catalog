require 'rails_helper'
require 'services/shared_examples_preserved_object_handler'

RSpec.describe PreservedObjectHandler do
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let!(:default_prez_policy) { PreservationPolicy.default_policy }
  let(:po) { PreservedObject.find_by(druid: druid) }
  let(:ep) { Endpoint.find_by(storage_location: 'spec/fixtures/storage_root01/moab_storage_trunk') }
  let(:pc) { PreservedCopy.find_by(preserved_object: po, endpoint: ep) }
  let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{ep})" }
  let(:db_update_failed_prefix_regex_escaped) { Regexp.escape("#{exp_msg_prefix} db update failed") }
  let(:po_handler) { described_class.new(druid, incoming_version, incoming_size, ep) }

  describe '#initialize' do
    it 'sets druid' do
      po_handler = described_class.new(druid, incoming_version, nil, ep)
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
          po_handler = described_class.new(druid, k, nil, ep)
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
          po_handler = described_class.new(druid, nil, k, ep)
          expect(po_handler.incoming_size).to eq v
        end
      end
    end
    it 'exposes storage_location (from endpoint)' do
      po_handler = described_class.new(druid, incoming_version, nil, ep)
      expect(po_handler.storage_location).to eq ep.storage_location
    end
    it 'sets endpoint' do
      po_handler = described_class.new(druid, incoming_version, nil, ep)
      expect(po_handler.endpoint).to eq ep
    end
  end

  describe '#check_existence' do
    context "(calls create or confirm_version)" do
      it 'calls #create_after_validation when the object does not exit' do
        expect(PreservedObject).to receive(:exists?).with(druid: druid).and_return(false)
        no_exist_msg = "#{exp_msg_prefix} PreservedObject db object does not exist"
        expect(Rails.logger).to receive(:log).with(Logger::ERROR, no_exist_msg)
        # because create_after_validation isn't called, we don't check
        # for the usual result codes it would return (doesn't exist and add to the db)
        expect(po_handler).to receive(:create_after_validation)
        po_handler.check_existence
      end

      it 'calls confirm_version when the object exists' do
        expect(PreservedObject).to receive(:exists?).with(druid: druid).and_return(true)
        expect(po_handler).to receive(:confirm_version)
        po_handler.check_existence
      end

      it 'calls update_version_after_validation when confirm_version returns ARG_VERSION_GREATER_THAN_DB_OBJECT' do
        expect(PreservedObject).to receive(:exists?).with(druid: druid).and_return(true)
        # only thing we care about here from confirm_version implementation is that it adds the result code we
        # want to test against, so just have it do that if it runs
        allow(po_handler).to receive(:confirm_version) do
          po_handler.handler_results.add_result(
            PreservedObjectHandlerResults::ARG_VERSION_GREATER_THAN_DB_OBJECT, 'PreservedObject'
          )
        end
        expect(po_handler).to receive(:update_version_after_validation)
        po_handler.check_existence
      end
    end

    it_behaves_like 'attributes validated', :check_existence

    context 'result handling' do
      let(:version_matches_po_msg) { "#{exp_msg_prefix} incoming version (6) matches PreservedObject db version" }
      let(:version_matches_pc_msg) { "#{exp_msg_prefix} incoming version (6) matches PreservedCopy db version" }
      let(:updated_pc_db_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }

      before do
        allow(po_handler).to receive(:moab_validation_errors).and_return([])
        allow(PreservedObject).to receive(:exists?).with(druid: druid).and_return(true)
        allow(po_handler).to receive(:confirm_version) do
          po_handler.handler_results.add_result(PreservedObjectHandlerResults::VERSION_MATCHES, 'PreservedObject')
          po_handler.handler_results.add_result(PreservedObjectHandlerResults::VERSION_MATCHES, 'PreservedCopy')
          po_handler.handler_results.add_result(PreservedObjectHandlerResults::UPDATED_DB_OBJECT, 'PreservedCopy')
        end
      end

      it 'returns the right number of result codes' do
        results = po_handler.check_existence
        expect(results.size).to eq 3
      end

      it 'VERSION_MATCHES results' do
        results = po_handler.check_existence
        code = PreservedObjectHandlerResults::VERSION_MATCHES
        expect(results).to include(a_hash_including(code => version_matches_pc_msg))
        expect(results).to include(a_hash_including(code => version_matches_po_msg))
      end

      it 'UPDATED_DB_OBJECT PreservedCopy result' do
        results = po_handler.check_existence
        code = PreservedObjectHandlerResults::UPDATED_DB_OBJECT
        expect(results).to include(a_hash_including(code => updated_pc_db_msg))
      end

      it "logs at info level" do
        expect(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_po_msg)
        expect(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_pc_msg)
        expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_msg)
        po_handler.check_existence
      end
    end
  end

  describe '#with_active_record_transaction_and_rescue' do
    it '#confirm_version rolls back preserved object if there is a problem updating preserved copy' do
      po = PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
      pc = PreservedCopy.create!(
        preserved_object: po,
        version: po.current_version,
        size: 1,
        endpoint: ep,
        status: PreservedCopy::DEFAULT_STATUS
      )
      bad_po_handler = described_class.new(druid, 6, incoming_size, ep)
      allow(pc).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError)
      bad_po_handler.confirm_version
      expect(PreservedObject.find_by(druid: druid).current_version).to eq 2
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
end
