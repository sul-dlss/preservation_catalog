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
  let(:ep) { Endpoint.find_by(storage_location: 'spec/fixtures/storage_root01/moab_storage_trunk') }
  let(:pc) { PreservedCopy.find_by(preserved_object: po, endpoint: ep) }
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
          endpoint_type: EndpointType.default_for_storage_roots,
          endpoint_node: 'localhost',
          storage_location: 'blah'
        )
        PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
        po_handler = described_class.new(druid, 3, incoming_size, diff_ep)
        results = po_handler.confirm_version
        code = AuditResults::DB_OBJ_DOES_NOT_EXIST
        exp_str = "ActiveRecord::RecordNotFound: Couldn't find PreservedCopy> db object does not exist"
        expect(results).to include(a_hash_including(code => a_string_matching(exp_str)))
        expect(PreservedObject.find_by(druid: druid).current_version).to eq 2
      end

      context "incoming and db versions match" do
        let(:po_handler) { described_class.new(druid, 2, 1, ep) }
        let(:version_matches_pc_msg) { "actual version (2) matches PreservedCopy db version" }

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
        it_behaves_like 'calls AuditResults.report_results', :confirm_version
        context 'returns' do
          let!(:results) { po_handler.confirm_version }

          it '1 result' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 1
          end
          it 'VERSION_MATCHES results' do
            code = AuditResults::VERSION_MATCHES
            expect(results).to include(a_hash_including(code => version_matches_pc_msg))
          end
        end
      end

      context 'PreservedCopy already has a status other than OK_STATUS' do
        it_behaves_like 'PreservedCopy may have its status checked when incoming_version == pc.version', :confirm_version

        it_behaves_like 'PreservedCopy may have its status checked when incoming_version < pc.version', :confirm_version

        context 'incoming_version > db version' do
          let(:incoming_version) { pc.version + 1 }

          it 'had OK_STATUS, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
            pc.status = PreservedCopy::OK_STATUS
            pc.save!
            allow(po_handler).to receive(:moab_validation_errors).and_return([])
            po_handler.confirm_version
            expect(pc.reload.status).to eq PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
          end
          it 'had INVALID_MOAB_STATUS, structure seems to be remediated, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
            pc.status = PreservedCopy::INVALID_MOAB_STATUS
            pc.save!
            allow(po_handler).to receive(:moab_validation_errors).and_return([])
            po_handler.confirm_version
            expect(pc.reload.status).to eq PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
          end
        end
      end

      context 'incoming version does NOT match db version' do
        let(:druid) { 'bj102hs9687' } # for shared_examples 'calls AuditResults.report_results'
        let(:po_handler) { described_class.new(druid, 1, 666, ep) }

        it_behaves_like 'calls AuditResults.report_results', :confirm_version

        context '' do
          before do
            # Note this context cannot work with shared_examples 'calls AuditResults.report_results
            allow(po_handler).to receive(:moab_validation_errors).and_return([])
          end

          context 'PreservedCopy' do
            context 'changed' do
              it 'status to unexpected_version_on_storage' do
                expect(pc.status).to eq PreservedCopy::OK_STATUS
                po_handler.confirm_version
                expect(pc.reload.status).to eq PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
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

          context 'returns' do
            let!(:results) { po_handler.confirm_version }

            it '2 results' do
              expect(results).to be_an_instance_of Array
              expect(results.size).to eq 2
            end
            it 'UNEXPECTED_VERSION PreservedCopy result' do
              code = AuditResults::UNEXPECTED_VERSION
              unexpected_version_pc_msg = "actual version (1) has unexpected relationship to PreservedCopy db version (2); ERROR!"
              expect(results).to include(a_hash_including(code => unexpected_version_pc_msg))
            end
            it "PC_STATUS_CHANGED PreservedCopy result" do
              code = AuditResults::PC_STATUS_CHANGED
              updated_pc_db_status_msg = "PreservedCopy status changed from ok to unexpected_version_on_storage"
              expect(results).to include(a_hash_including(code => updated_pc_db_status_msg))
            end
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
          let(:result_code) { AuditResults::DB_UPDATE_FAILED }
          let(:incoming_version) { 2 }
          let(:results) do

            po = instance_double("PreservedObject")
            allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
            pc = instance_double("PreservedCopy")
            allow(PreservedCopy).to receive(:find_by).and_return(pc)
            allow(pc).to receive(:version).and_return(2)
            allow(pc).to receive(:status)
            allow(pc).to receive(:update_status)
            allow(pc).to receive(:update_audit_timestamps)
            allow(pc).to receive(:changed?).and_return(true)
            allow(pc).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
            allow(pc).to receive(:matches_po_current_version?).and_return(true)
            allow(po).to receive(:current_version).and_return(2)
            allow(po_handler).to receive(:moab_validation_errors).and_return([])
            po_handler.confirm_version
          end

          it 'DB_UPDATE_FAILED error' do
            expect(results).to include(a_hash_including(AuditResults::DB_UPDATE_FAILED))
          end
        end
      end

      it 'calls PreservedCopy.save! (but not PreservedObject.save!) if the existing record is altered' do
        po = instance_double(PreservedObject)
        pc = instance_double(PreservedCopy)
        status = PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(po).to receive(:save!)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:update_status).with(status)
        allow(pc).to receive(:update_audit_timestamps)
        allow(pc).to receive(:changed?).and_return(true)
        allow(pc).to receive(:save!)
        allow(pc).to receive(:matches_po_current_version?).and_return(true)
        allow(pc).to receive(:status).and_return(PreservedCopy::OK_STATUS)
        allow(po_handler).to receive(:moab_validation_errors).and_return([])
        po_handler.confirm_version
        expect(po).not_to have_received(:save!)
        expect(pc).to have_received(:save!)
      end
      it 'calls PreservedCopy.save! (but not PreservedObject.save!) if the existing record is NOT altered' do
        po_handler = described_class.new(druid, 1, 1, ep)
        po = instance_double(PreservedObject)
        pc = instance_double(PreservedCopy)
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        allow(po).to receive(:current_version).and_return(1)
        allow(PreservedCopy).to receive(:find_by).with(preserved_object: po, endpoint: ep).and_return(pc)
        allow(pc).to receive(:status).and_return(PreservedCopy::OK_STATUS)
        allow(pc).to receive(:version).and_return(1)
        allow(pc).to receive(:update_audit_timestamps)
        allow(pc).to receive(:changed?).and_return(false)
        allow(po).to receive(:save!)
        allow(pc).to receive(:save!)
        allow(pc).to receive(:matches_po_current_version?).and_return(true)
        po_handler.confirm_version
        expect(pc).to have_received(:save!)
        expect(po).not_to have_received(:save!)
      end
      it 'logs a debug message' do
        msg = "confirm_version #{druid} called"
        allow(Rails.logger).to receive(:debug)
        allow(po_handler).to receive(:moab_validation_errors).and_return([])
        po_handler.confirm_version
        expect(Rails.logger).to have_received(:debug).with(msg)
      end
    end

    it_behaves_like 'druid not in catalog', :confirm_version

    it_behaves_like 'PreservedCopy does not exist', :confirm_version
  end
end
