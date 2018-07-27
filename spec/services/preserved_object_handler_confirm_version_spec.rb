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
  let(:po) { PreservedObject.find_by!(druid: druid) }
  let(:ms_root) { MoabStorageRoot.find_by!(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  let(:cm) { po.complete_moabs.find_by!(moab_storage_root: ms_root) }
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
        create(:preserved_object, druid: druid, current_version: 2)
        po_handler = described_class.new(druid, 3, incoming_size, diff_root)
        results = po_handler.confirm_version
        exp_str = "ActiveRecord::RecordNotFound: Couldn't find CompleteMoab.* db object does not exist"
        expect(results).to include(a_hash_including(AuditResults::DB_OBJ_DOES_NOT_EXIST => a_string_matching(exp_str)))
        expect(PreservedObject.find_by(druid: druid).current_version).to eq 2
      end

      context "incoming and db versions match" do
        let(:po_handler) { described_class.new(druid, 2, 1, ms_root) }
        let(:version_matches_cm_msg) { "actual version (2) matches CompleteMoab db version" }

        context 'CompleteMoab' do
          context 'changed' do
            it 'last_version_audit' do
              expect { po_handler.confirm_version }.to change { po_handler.complete_moab.last_version_audit }
            end
            it 'updated_at' do
              expect { po_handler.confirm_version }.to change { po_handler.complete_moab.reload.updated_at }
            end
          end

          context 'unchanged' do
            it 'status' do
              expect { po_handler.confirm_version }.not_to change { po_handler.complete_moab.status }
            end
            it 'version' do
              expect { po_handler.confirm_version }.not_to change { po_handler.complete_moab.version }
            end
            it 'size' do
              expect { po_handler.confirm_version }.not_to change { po_handler.complete_moab.size }
            end
            it 'last_moab_validation' do
              expect { po_handler.confirm_version }.not_to change { po_handler.complete_moab.last_moab_validation }
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
          let(:results) { po_handler.confirm_version }

          it '1 result of VERSION_MATCHES' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 1
            expect(results.first).to match(a_hash_including(AuditResults::VERSION_MATCHES => version_matches_cm_msg))
          end
        end
      end

      context 'CompleteMoab already has a status other than OK_STATUS' do
        it_behaves_like 'CompleteMoab may have its status checked when incoming_version == cm.version', :confirm_version

        it_behaves_like 'CompleteMoab may have its status checked when incoming_version < cm.version', :confirm_version

        context 'incoming_version > db version' do
          let(:incoming_version) { cm.version + 1 }

          before { allow(po_handler).to receive(:moab_validation_errors).and_return([]) }

          it 'had OK_STATUS, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
            cm.ok!
            po_handler.confirm_version
            expect(cm.reload.status).to eq 'unexpected_version_on_storage'
          end
          it 'had INVALID_MOAB_STATUS, structure seems to be remediated, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
            cm.invalid_moab!
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
          before { allow(po_handler).to receive(:moab_validation_errors).and_return([]) }
          # Note this context cannot work with shared_examples 'calls AuditResults.report_results

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

      context 'db update error (ActiveRecordError)' do
        let(:result_code) { AuditResults::DB_UPDATE_FAILED }
        let(:incoming_version) { 2 }

        before do
          po = create(:preserved_object, current_version: 2)
          cm = create(:complete_moab, preserved_object: po, version: po.current_version)
          allow(PreservedObject).to receive(:find_by!).with(druid: druid).and_return(po)
          allow(po.complete_moabs).to receive(:find_by!).and_return(cm)
          allow(po_handler).to receive(:moab_validation_errors).and_return([])
          allow(cm).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
        end

        it 'DB_UPDATE_FAILED error' do
          expect(po_handler.confirm_version).to include(a_hash_including(AuditResults::DB_UPDATE_FAILED))
        end
      end

      describe 'calls CompleteMoab.save! (but not PreservedObject.save!)' do
        before do
          allow(PreservedObject).to receive(:find_by).with(druid: druid).and_return(po)
          allow(po.complete_moabs).to receive(:find_by!).with(moab_storage_root: ms_root).and_return(cm)
        end
        it 'if the existing record is altered' do
          allow(po_handler).to receive(:moab_validation_errors).and_return([])
          expect(cm).to receive(:save!)
          expect(po).not_to receive(:save!)
          po_handler.confirm_version
        end
        it 'calls CompleteMoab.save! (but not PreservedObject.save!) if the existing record is NOT altered' do
          po_handler = described_class.new(druid, 1, 1, ms_root)
          allow(po_handler).to receive(:moab_validation_errors).and_return([]) # different po_handler now
          expect(cm).to receive(:save!)
          expect(po).not_to receive(:save!)
          po_handler.confirm_version
        end
      end

      it 'logs a debug message' do
        allow(Rails.logger).to receive(:debug)
        expect(Rails.logger).to receive(:debug).with("confirm_version #{druid} called")
        allow(po_handler).to receive(:moab_validation_errors).and_return([])
        po_handler.confirm_version
      end
    end

    it_behaves_like 'druid not in catalog', :confirm_version

    it_behaves_like 'CompleteMoab does not exist', :confirm_version
  end
end
