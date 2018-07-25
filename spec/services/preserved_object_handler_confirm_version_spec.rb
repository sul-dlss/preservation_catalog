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

  describe '#confirm_version' do
    it_behaves_like 'attributes validated', :confirm_version

    context 'druid in db' do
      before do
        po = PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
        CompleteMoab.create!(
          preserved_object: po,
          version: po.current_version,
          size: 1,
          moab_storage_root: ms_root,
          status: 'ok' # NOTE: we are pretending we checked for moab validation errs
        )
      end

      it 'stops processing if there is no CompleteMoab' do
        druid = 'nd000lm0000'
        diff_root = MoabStorageRoot.create!(
          name: 'diff_root',
          storage_location: 'blah'
        )
        PreservedObject.create!(druid: druid, current_version: 2, preservation_policy: default_prez_policy)
        po_handler = described_class.new(druid, 3, incoming_size, diff_root)
        results = po_handler.confirm_version
        code = AuditResults::DB_OBJ_DOES_NOT_EXIST
        exp_str = "ActiveRecord::RecordNotFound: Couldn't find CompleteMoab> db object does not exist"
        expect(results).to include(a_hash_including(code => a_string_matching(exp_str)))
        expect(PreservedObject.find_by(druid: druid).current_version).to eq 2
      end

      context "incoming and db versions match" do
        let(:po_handler) { described_class.new(druid, 2, 1, ms_root) }
        let(:version_matches_cm_msg) { "actual version (2) matches CompleteMoab db version" }

        context 'CompleteMoab' do
          context 'changed' do
            it 'last_version_audit' do
              orig = Time.current
              cm.last_version_audit = orig
              cm.save!
              po_handler.confirm_version
              expect(cm.reload.last_version_audit).to be > orig
            end
            it 'updated_at' do
              orig = cm.updated_at
              po_handler.confirm_version
              expect(cm.reload.updated_at).to be > orig
            end
          end
          context 'unchanged' do
            it 'status' do
              orig = cm.status
              po_handler.confirm_version
              expect(cm.reload.status).to eq orig
            end
            it 'version' do
              orig = cm.version
              po_handler.confirm_version
              expect(cm.reload.version).to eq orig
            end
            it 'size' do
              orig = cm.size
              po_handler.confirm_version
              expect(cm.reload.size).to eq orig
            end
            it 'last_moab_validation' do
              orig = cm.last_moab_validation
              po_handler.confirm_version
              expect(cm.reload.last_moab_validation).to eq orig
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
            expect(results).to include(a_hash_including(code => version_matches_cm_msg))
          end
        end
      end

      context 'CompleteMoab already has a status other than OK_STATUS' do
        it_behaves_like 'CompleteMoab may have its status checked when incoming_version == cm.version', :confirm_version

        it_behaves_like 'CompleteMoab may have its status checked when incoming_version < cm.version', :confirm_version

        context 'incoming_version > db version' do
          let(:incoming_version) { cm.version + 1 }

          it 'had OK_STATUS, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
            cm.status = 'ok'
            cm.save!
            allow(po_handler).to receive(:moab_validation_errors).and_return([])
            po_handler.confirm_version
            expect(cm.reload.status).to eq 'unexpected_version_on_storage'
          end
          it 'had INVALID_MOAB_STATUS, structure seems to be remediated, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
            cm.status = 'invalid_moab'
            cm.save!
            allow(po_handler).to receive(:moab_validation_errors).and_return([])
            po_handler.confirm_version
            expect(cm.reload.status).to eq 'unexpected_version_on_storage'
          end
        end
      end

      context 'incoming version does NOT match db version' do
        let(:druid) { 'bj102hs9687' } # for shared_examples 'calls AuditResults.report_results'
        let(:po_handler) { described_class.new(druid, 1, 666, ms_root) }

        it_behaves_like 'calls AuditResults.report_results', :confirm_version

        context '' do
          before do
            # Note this context cannot work with shared_examples 'calls AuditResults.report_results
            allow(po_handler).to receive(:moab_validation_errors).and_return([])
          end

          context 'CompleteMoab' do
            context 'changed' do
              it 'status to unexpected_version_on_storage' do
                expect(cm.status).to eq 'ok'
                po_handler.confirm_version
                expect(cm.reload.status).to eq 'unexpected_version_on_storage'
              end
              it 'last_version_audit' do
                orig = Time.current
                cm.last_version_audit = orig
                cm.save!
                po_handler.confirm_version
                expect(cm.reload.last_version_audit).to be > orig
              end
              it 'updated_at' do
                orig = cm.updated_at
                po_handler.confirm_version
                expect(cm.reload.updated_at).to be > orig
              end
            end
            context 'unchanged' do
              it 'version' do
                orig = cm.version
                po_handler.confirm_version
                expect(cm.reload.version).to eq orig
              end
              it 'size' do
                orig = cm.size
                po_handler.confirm_version
                expect(cm.reload.size).to eq orig
              end
              it 'last_moab_validation' do
                orig = cm.last_moab_validation
                po_handler.confirm_version
                expect(cm.reload.last_moab_validation).to eq orig
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
            it 'UNEXPECTED_VERSION CompleteMoab result' do
              code = AuditResults::UNEXPECTED_VERSION
              unexpected_version_cm_msg = "actual version (1) has unexpected relationship to CompleteMoab db version (2); ERROR!"
              expect(results).to include(a_hash_including(code => unexpected_version_cm_msg))
            end
            it "CM_STATUS_CHANGED CompleteMoab result" do
              code = AuditResults::CM_STATUS_CHANGED
              updated_cm_db_status_msg = "CompleteMoab status changed from ok to unexpected_version_on_storage"
              expect(results).to include(a_hash_including(code => updated_cm_db_status_msg))
            end
          end
        end
      end

      context 'CompleteMoab version does NOT match PreservedObject current_version (online Moab)' do
        before do
          po.current_version = 8
          po.save!
        end

        it_behaves_like 'PreservedObject current_version does not match online CM version', :confirm_version, 3, 2, 8
      end

      context 'db update error' do
        context 'ActiveRecordError' do
          let(:result_code) { AuditResults::DB_UPDATE_FAILED }
          let(:incoming_version) { 2 }
          let(:results) do
            po = create :preserved_object, current_version: 2
            allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
            cm = create :complete_moab, preserved_object: po, version: 2
            allow(CompleteMoab).to receive(:find_by).and_return(cm)
            allow(po_handler).to receive(:moab_validation_errors).and_return([])

            allow(cm).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
            po_handler.confirm_version
          end

          it 'DB_UPDATE_FAILED error' do
            expect(results).to include(a_hash_including(AuditResults::DB_UPDATE_FAILED))
          end
        end
      end

      it 'calls CompleteMoab.save! (but not PreservedObject.save!) if the existing record is altered' do
        po = create :preserved_object
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        cm = create :complete_moab, preserved_object: po
        allow(CompleteMoab).to receive(:find_by).with(preserved_object: po, moab_storage_root: ms_root).and_return(cm)
        allow(po_handler).to receive(:moab_validation_errors).and_return([])

        allow(po).to receive(:save!)
        allow(cm).to receive(:save!)
        po_handler.confirm_version
        expect(po).not_to have_received(:save!)
        expect(cm).to have_received(:save!)
      end
      it 'calls CompleteMoab.save! (but not PreservedObject.save!) if the existing record is NOT altered' do
        po_handler = described_class.new(druid, 1, 1, ms_root)
        po = create :preserved_object
        allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
        cm = create :complete_moab, preserved_object: po
        allow(CompleteMoab).to receive(:find_by).with(preserved_object: po, moab_storage_root: ms_root).and_return(cm)

        allow(po).to receive(:save!)
        allow(cm).to receive(:save!)
        po_handler.confirm_version
        expect(cm).to have_received(:save!)
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

    it_behaves_like 'CompleteMoab does not exist', :confirm_version
  end
end
