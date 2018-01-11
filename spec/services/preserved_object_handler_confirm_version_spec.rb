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
  let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, #{incoming_version}, #{incoming_size}, #{ep.endpoint_name})" }
  let(:db_update_failed_prefix_regex_escaped) { Regexp.escape("#{exp_msg_prefix} db update failed") }
  let(:po_handler) { described_class.new(druid, incoming_version, incoming_size, ep) }

  describe '#confirm_version' do
    it_behaves_like 'attributes validated', :confirm_version

    context 'druid in db' do
      before do
        po = PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
        PreservedCopy.create!(
          preserved_object: po,
          version: po.current_version,
          size: 1,
          endpoint: ep,
          status: PreservedCopy::OK_STATUS # NOTE: we are pretending we checked for moab validation errs
        )
      end

      it 'stops processing if there is no PreservedCopy' do
        druid = 'nd000lm0000'
        diff_ep = Endpoint.create!(
          endpoint_name: 'diff_endpoint',
          endpoint_type: Endpoint.default_storage_root_endpoint_type,
          endpoint_node: 'localhost',
          storage_location: 'blah',
          recovery_cost: 1
        )
        PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
        po_handler = described_class.new(druid, 3, incoming_size, diff_ep)
        results = po_handler.confirm_version
        code = PreservedObjectHandlerResults::OBJECT_DOES_NOT_EXIST
        exp_str = "ActiveRecord::RecordNotFound: Couldn't find PreservedCopy> db object does not exist"
        expect(results).to include(a_hash_including(code => a_string_matching(exp_str)))
        expect(PreservedObject.find_by(druid: druid).current_version).to eq 2
      end

      context "incoming and db versions match" do
        let(:po_handler) { described_class.new(druid, 2, 1, ep) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 2, 1, #{ep.endpoint_name})" }
        let(:version_matches_po_msg) { "#{exp_msg_prefix} incoming version (2) matches PreservedObject db version" }
        let(:version_matches_pc_msg) { "#{exp_msg_prefix} incoming version (2) matches PreservedCopy db version" }
        let(:updated_pc_db_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }

        context 'PreservedCopy' do
          context 'changed' do
            it 'last_version_audit' do
              orig = Time.current
              pc.last_version_audit = orig
              pc.save!
              po_handler.confirm_version
              expect(pc.reload.last_version_audit).to be > orig
            end
            it 'updated_at' do
              orig = pc.updated_at
              po_handler.confirm_version
              expect(pc.reload.updated_at).to be > orig
            end
          end
          context 'unchanged' do
            it 'status' do
              orig = pc.status
              po_handler.confirm_version
              expect(pc.reload.status).to eq orig
            end
            it 'version' do
              orig = pc.version
              po_handler.confirm_version
              expect(pc.reload.version).to eq orig
            end
            it 'size' do
              orig = pc.size
              po_handler.confirm_version
              expect(pc.reload.size).to eq orig
            end
            it 'last_moab_validation' do
              orig = pc.last_moab_validation
              po_handler.confirm_version
              expect(pc.reload.last_moab_validation).to eq orig
            end
          end
        end
        it 'PreservedObject is not updated' do
          orig_timestamp = po.updated_at
          po_handler.confirm_version
          expect(po.reload.updated_at).to eq orig_timestamp
        end
        it "logs at info level" do
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_po_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, version_matches_pc_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_msg)
          po_handler.confirm_version
        end
        context 'returns' do
          let!(:results) { po_handler.confirm_version }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '3 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 3
          end
          it 'VERSION_MATCHES results' do
            code = PreservedObjectHandlerResults::VERSION_MATCHES
            expect(results).to include(a_hash_including(code => version_matches_pc_msg))
            expect(results).to include(a_hash_including(code => version_matches_po_msg))
          end
          it 'UPDATED_DB_OBJECT PreservedCopy result' do
            code = PreservedObjectHandlerResults::UPDATED_DB_OBJECT
            expect(results).to include(a_hash_including(code => updated_pc_db_msg))
          end
        end
      end

      context 'incoming version does NOT match db version' do
        let(:po_handler) { described_class.new(druid, 1, 666, ep) }
        let(:exp_msg_prefix) { "PreservedObjectHandler(#{druid}, 1, 666, #{ep.endpoint_name})" }
        let(:unexpected_version_pc_msg) {
          "#{exp_msg_prefix} incoming version (1) has unexpected relationship to PreservedCopy db version; ERROR!"
        }
        let(:updated_pc_db_status_msg) {
          "#{exp_msg_prefix} PreservedCopy status changed from ok to expected_vers_not_found_on_storage"
        }
        let(:updated_pc_db_obj_msg) { "#{exp_msg_prefix} PreservedCopy db object updated" }

        context 'PreservedCopy' do
          context 'changed' do
            it 'status to expected_vers_not_found_on_storage' do
              expect(pc.status).to eq PreservedCopy::OK_STATUS
              po_handler.confirm_version
              expect(pc.reload.status).to eq PreservedCopy::EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS
            end
            it 'last_version_audit' do
              orig = Time.current
              pc.last_version_audit = orig
              pc.save!
              po_handler.confirm_version
              expect(pc.reload.last_version_audit).to be > orig
            end
            it 'updated_at' do
              orig = pc.updated_at
              po_handler.confirm_version
              expect(pc.reload.updated_at).to be > orig
            end
          end
          context 'unchanged' do
            it 'version' do
              orig = pc.version
              po_handler.confirm_version
              expect(pc.reload.version).to eq orig
            end
            it 'size' do
              orig = pc.size
              po_handler.confirm_version
              expect(pc.reload.size).to eq orig
            end
            it 'last_moab_validation' do
              orig = pc.last_moab_validation
              po_handler.confirm_version
              expect(pc.reload.last_moab_validation).to eq orig
            end
          end
        end
        it 'PreservedObject is not updated' do
          orig_timestamp = po.updated_at
          po_handler.confirm_version
          expect(po.reload.updated_at).to eq orig_timestamp
        end

        it "logs at error level" do
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_status_msg)
          expect(Rails.logger).to receive(:log).with(Logger::ERROR, unexpected_version_pc_msg)
          expect(Rails.logger).to receive(:log).with(Logger::INFO, updated_pc_db_obj_msg)
          po_handler.confirm_version
        end
        context 'returns' do
          let!(:results) { po_handler.confirm_version }

          # results = [result1, result2]
          # result1 = {response_code: msg}
          # result2 = {response_code: msg}
          it '3 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 3
          end
          it 'UNEXPECTED_VERSION PreservedCopy result' do
            code = PreservedObjectHandlerResults::UNEXPECTED_VERSION
            expect(results).to include(a_hash_including(code => unexpected_version_pc_msg))
          end
          it 'UPDATED_DB_OBJECT PreservedCopy result' do
            code = PreservedObjectHandlerResults::UPDATED_DB_OBJECT
            expect(results).to include(a_hash_including(code => updated_pc_db_obj_msg))
          end
          it "PC_STATUS_CHANGED PreservedCopy result" do
            code = PreservedObjectHandlerResults::PC_STATUS_CHANGED
            expect(results).to include(a_hash_including(code => updated_pc_db_status_msg))
          end
        end
      end

      context 'PreservedCopy version does NOT match PreservedObject current_version (online Moab)' do
        before do
          po.current_version = 8
          po.save!
        end

        it_behaves_like 'PreservedObject current_version does not match online PC version', :confirm_version, 3, 2, 8
      end

      context 'db update error' do
        context 'ActiveRecordError' do
          let(:result_code) { PreservedObjectHandlerResults::DB_UPDATE_FAILED }
          let(:incoming_version) { 2 }
          let(:results) do

            po = instance_double("PreservedObject")
            allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
            pc = instance_double("PreservedCopy")
            allow(PreservedCopy).to receive(:find_by).and_return(pc)
            allow(pc).to receive(:version).and_return(2)
            allow(pc).to receive(:status)
            allow(pc).to receive(:status=)
            allow(pc).to receive(:last_version_audit=)
            allow(pc).to receive(:changed?).and_return(true)
            allow(pc).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
            allow(po).to receive(:current_version).and_return(2)
            allow(po_handler).to receive(:moab_validation_errors).and_return([])
            po_handler.confirm_version
          end

          it 'DB_UPDATE_FAILED error' do
            expect(results).to include(a_hash_including(PreservedObjectHandlerResults::DB_UPDATE_FAILED))
          end
        end
      end

      it 'calls PreservedCopy.save! (but not PreservedObject.save!) if the existing record is altered' do
        po = instance_double(PreservedObject)
        pc = instance_double(PreservedCopy)
        status = PreservedCopy::EXPECTED_VERS_NOT_FOUND_ON_STORAGE_STATUS
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:save!)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:status).and_return(status)
        allow(pc).to receive(:last_version_audit=)
        allow(pc).to receive(:changed?).and_return(true)
        allow(pc).to receive(:save!)
        allow(po_handler).to receive(:moab_validation_errors).and_return([])
        po_handler.confirm_version
        expect(po).not_to have_received(:save!)
        expect(pc).to have_received(:save!)
      end
      it 'calls PreservedCopy.touch (but not PreservedObject.touch) if the existing record is NOT altered' do
        po_handler = described_class.new(druid, 1, 1, ep)
        po = instance_double(PreservedObject)
        pc = instance_double(PreservedCopy)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:touch)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:status).and_return(PreservedCopy::OK_STATUS)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:last_version_audit=)
        allow(pc).to receive(:changed?).and_return(false)
        allow(pc).to receive(:touch)
        po_handler.confirm_version
        expect(po).not_to have_received(:touch)
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
end
