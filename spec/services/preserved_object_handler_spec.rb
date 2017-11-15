require 'rails_helper'
require 'services/shared_examples_preserved_object_handler'

RSpec.describe PreservedObjectHandler do
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let!(:default_prez_policy) { PreservationPolicy.default_preservation_policy }
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

  describe '#confirm_version' do
    it_behaves_like 'attributes validated', :confirm_version

    context 'druid in db' do
      before do
        po = PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
        PreservedCopy.create!(
          preserved_object: po, # TODO: see if we got the preserved object that we expected
          version: po.current_version,
          size: 1,
          endpoint: ep,
          status: Status.default_status
        )
      end

      context "incoming and db versions match" do
        let(:po_handler) { described_class.new(druid, 2, 1, ep) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 2, 1, #{ep})" }
        let(:version_matches_po_msg) { "#{exp_msg_prefix} incoming version (2) matches PreservedObject db version" }
        let(:version_matches_pc_msg) { "#{exp_msg_prefix} incoming version (2) matches PreservedCopy db version" }
        let(:updated_po_db_timestamp_msg) { "#{exp_msg_prefix} PreservedObject updated db timestamp only" }
        let(:updated_pc_db_timestamp_msg) { "#{exp_msg_prefix} PreservedCopy updated db timestamp only" }

        it "entry version stays the same" do
          expect(po.current_version).to eq 2
          expect(pc.version).to eq 2
          po_handler.confirm_version
          expect(po.reload.current_version).to eq 2
          expect(pc.reload.version).to eq 2
        end
        it "entry size stays the same" do
          expect(pc.size).to eq 1
          po_handler.confirm_version
          expect(pc.reload.size).to eq 1
        end
        it "logs at info level" do
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_po_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_pc_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_po_db_timestamp_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_timestamp_msg)
          po_handler.confirm_version
        end
        context 'returns' do
          let!(:results) { po_handler.confirm_version }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '4 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 4
          end
          it 'VERSION_MATCHES results' do
            code = PreservedObjectHandler::VERSION_MATCHES
            expect(results).to include(a_hash_including(code => version_matches_pc_msg))
            expect(results).to include(a_hash_including(code => version_matches_po_msg))
          end
          it 'UPDATED_DB_OBJECT_TIMESTAMP_ONLY results' do
            code = PreservedObjectHandler::UPDATED_DB_OBJECT_TIMESTAMP_ONLY
            expect(results).to include(a_hash_including(code => updated_pc_db_timestamp_msg))
            expect(results).to include(a_hash_including(code => updated_po_db_timestamp_msg))
          end
        end
      end
      context 'incoming version newer than db version' do
        let(:version_gt_po_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than PreservedObject db version" }
        let(:version_gt_pc_msg) { "#{exp_msg_prefix} incoming version (#{incoming_version}) greater than PreservedCopy db version" }

        let(:updated_po_db_msg) { "#{exp_msg_prefix} PreservedObject db object updated" }
        let(:updated_pc_db_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }

        it "updates entry with incoming version" do
          expect(po.current_version).to eq 2
          expect(pc.version).to eq 2
          po_handler.confirm_version
          expect(po.reload.current_version).to eq incoming_version
          expect(pc.reload.version).to eq incoming_version
        end
        it 'updates entry with size if included' do
          expect(pc.size).to eq 1
          po_handler.confirm_version
          expect(pc.reload.size).to eq incoming_size
        end
        it 'retains old size if incoming size is nil' do
          expect(pc.size).to eq 1
          po_handler = described_class.new(druid, incoming_version, nil, ep)
          po_handler.confirm_version
          expect(pc.reload.size).to eq 1
        end
        it "logs at info level" do
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_po_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_gt_pc_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_po_db_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_msg)
          po_handler.confirm_version
        end
        context 'returns' do
          let!(:results) { po_handler.confirm_version }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '4 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 4
          end
          it 'ARG_VERSION_GREATER_THAN_DB_OBJECT results' do
            code = PreservedObjectHandler::ARG_VERSION_GREATER_THAN_DB_OBJECT
            expect(results).to include(a_hash_including(code => version_gt_pc_msg))
            expect(results).to include(a_hash_including(code => version_gt_po_msg))
          end
          it 'UPDATED_DB_OBJECT results' do
            code = PreservedObjectHandler::UPDATED_DB_OBJECT
            expect(results).to include(a_hash_including(code => updated_pc_db_msg))
            expect(results).to include(a_hash_including(code => updated_po_db_msg))
          end
        end
      end

      context 'incoming version older than db version' do
        let(:po_handler) { described_class.new(druid, 1, 666, ep) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 1, 666, #{ep})" }
        let(:version_less_than_po_msg) { "#{exp_msg_prefix} incoming version (1) less than PreservedObject db version; ERROR!" }
        let(:version_less_than_pc_msg) { "#{exp_msg_prefix} incoming version (1) less than PreservedCopy db version; ERROR!" }
        let(:updated_po_db_timestamp_msg) { "#{exp_msg_prefix} PreservedObject updated db timestamp only" }
        let(:updated_pc_db_obj_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }
        let(:updated_pc_db_status_msg) do
          "#{exp_msg_prefix} PreservedCopy status changed from ok to expected_version_not_found_on_disk"
        end

        it "entry version stays the same" do
          expect(po.current_version).to eq 2
          expect(pc.version).to eq 2
          po_handler.confirm_version
          expect(po.reload.current_version).to eq 2
          expect(pc.reload.version).to eq 2
        end
        it "entry size stays the same" do
          expect(pc.size).to eq 1
          po_handler.confirm_version
          expect(pc.reload.size).to eq 1
        end
        it "logs at error level" do
          expect(Rails.logger).to receive(:log).with(Logger::ERROR, version_less_than_po_msg)
          expect(Rails.logger).to receive(:log).with(Logger::ERROR, version_less_than_pc_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_po_db_timestamp_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_obj_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_status_msg)
          po_handler.confirm_version
        end
        context 'returns' do
          let!(:results) { po_handler.confirm_version }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '5 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 5
          end
          it 'ARG_VERSION_LESS_THAN_DB_OBJECT results' do
            code = PreservedObjectHandler::ARG_VERSION_LESS_THAN_DB_OBJECT
            expect(results).to include(a_hash_including(code => version_less_than_pc_msg))
            expect(results).to include(a_hash_including(code => version_less_than_po_msg))
          end
          # FIXME: do we want to update timestamp if we found an error (ARG_VERSION_LESS_THAN_DB_OBJECT)
          it "PreservedObject UPDATED_DB_OBJECT_TIMESTAMP_ONLY result" do
            code = PreservedObjectHandler::UPDATED_DB_OBJECT_TIMESTAMP_ONLY
            expect(results).to include(a_hash_including(code => updated_po_db_timestamp_msg))
          end
          it "PreservedCopy UPDATED_DB_OBJECT result" do
            code = PreservedObjectHandler::UPDATED_DB_OBJECT
            expect(results).to include(a_hash_including(code => updated_pc_db_obj_msg))
          end
          it "PreservedCopy PC_STATUS_CHANGED result" do
            code = PreservedObjectHandler::PC_STATUS_CHANGED
            expect(results).to include(a_hash_including(code => updated_pc_db_status_msg))
          end
        end
      end
      context 'db update error' do
        context 'ActiveRecordError' do
          let(:result_code) { PreservedObjectHandler::DB_UPDATE_FAILED }
          let(:results) do
            allow(Rails.logger).to receive(:log)
            # FIXME: couldn't figure out how to put next line into its own test
            expect(Rails.logger).to receive(:log).with(Logger::ERROR, /#{db_update_failed_prefix_regex_escaped}/)

            po = instance_double("PreservedObject")
            allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
            allow(po).to receive(:current_version).and_return(1)
            allow(po).to receive(:current_version=).with(incoming_version)
            allow(po).to receive(:changed?).and_return(true)
            allow(po).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
            allow(po).to receive(:destroy) # for after() cleanup calls
            po_handler.confirm_version
          end

          context 'DB_UPDATE_FAILED error' do
            it 'prefix' do
              expect(results).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix_regex_escaped)))
            end
            it 'specific exception raised' do
              expect(results).to include(a_hash_including(result_code => a_string_matching('ActiveRecord::ActiveRecordError')))
            end
            it "exception's message" do
              expect(results).to include(a_hash_including(result_code => a_string_matching('foo')))
            end
          end
        end
      end
      it 'calls PreservedObject.save! and PreservedCopy.save! if the existing record is altered' do
        po = instance_double(PreservedObject)
        pc = instance_double(PreservedCopy)

        # bad object-oriented form!  type checking like this is to be avoided.  but also, wouldn't
        # it be nice if an rspec double returned `true` when asked if it was an instance or kind of
        # the object type being mocked?  i think that'd be nice.  but that's not what doubles do.
        allow(po).to receive(:is_a?).with(PreservedObject).and_return(true)
        allow(po).to receive(:is_a?).with(PreservedCopy).and_return(false)
        allow(pc).to receive(:is_a?).with(PreservedObject).and_return(false)
        allow(pc).to receive(:is_a?).with(PreservedCopy).and_return(true)

        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:current_version=).with(incoming_version)
        allow(po).to receive(:changed?).and_return(true)
        allow(po).to receive(:save!)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:version=).with(incoming_version)
        allow(pc).to receive(:size=).with(incoming_size)
        allow(pc).to receive(:endpoint).with(ep)
        allow(pc).to receive(:changed?).and_return(true)
        allow(pc).to receive(:status).and_return(Status.ok)
        allow(pc).to receive(:save!)
        po_handler.confirm_version
        expect(po).to have_received(:save!)
        expect(pc).to have_received(:save!)
      end
      it 'calls PreservedObject.touch and PreservedCopy.touch if the existing record is NOT altered' do
        po_handler = described_class.new(druid, 1, 1, ep)
        po = instance_double(PreservedObject)
        pc = instance_double(PreservedCopy)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:changed?).and_return(false)
        allow(po).to receive(:touch)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:endpoint).with(ep)
        allow(pc).to receive(:changed?).and_return(false)
        allow(pc).to receive(:touch)
        po_handler.confirm_version
        expect(po).to have_received(:touch)
        expect(pc).to have_received(:touch)
      end
      it 'logs a debug message' do
        msg = "confirm_version #{druid} called"
        allow(Rails.logger).to receive(:debug)
        po_handler.confirm_version
        expect(Rails.logger).to have_received(:debug).with(msg)
      end
    end

    it_behaves_like 'druid not in catalog', :confirm_version

    it_behaves_like 'PreservedCopy does not exist', :confirm_version
  end

  describe '#with_active_record_transaction_and_rescue' do
    context 'bogus endpoint' do
      let(:wrong_ep) do
        Endpoint.create!(
          endpoint_name: 'wrong_endpoint',
          endpoint_type: Endpoint.default_storage_root_endpoint_type,
          endpoint_node: 'localhost',
          storage_location: 'blah',
          recovery_cost: 1
        )
      end
      let(:bad_po_handler) { described_class.new(druid, 6, incoming_size, wrong_ep) }

      before do
        po = PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
        PreservedCopy.create!(
          preserved_object: po, # TODO: see if we got the preserved object that we expected
          version: po.current_version,
          size: 1,
          endpoint: ep,
          status: Status.default_status
        )
      end

      it '#confirm_version rolls back preserved object if the preserved copy cannot be found' do
        bad_po_handler.confirm_version
        expect(PreservedObject.find_by(druid: druid).current_version).to eq 2
      end
    end
  end
end
