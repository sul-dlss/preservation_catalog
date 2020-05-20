# frozen_string_literal: true

require 'rails_helper'
require 'services/shared_examples_complete_moab_handler'

RSpec.describe CompleteMoabHandler do
  before do
    allow(WorkflowReporter).to receive(:report_error)
  end

  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let(:ms_root) { create(:moab_storage_root) }
  let(:complete_moab_handler) { described_class.new(druid, incoming_version, incoming_size, ms_root) }

  describe '#confirm_version' do
    it_behaves_like 'attributes validated', :confirm_version

    context 'druid in db' do
      let(:druid) { 'ab123cd4567' } # doesn't exist among fixtures on disk
      let(:po_current_version) { 2 }
      let(:cm_version) { po_current_version }
      let!(:po) { create(:preserved_object, druid: druid, current_version: po_current_version) }
      let!(:cm) do
        create(:complete_moab, preserved_object: po, version: cm_version, moab_storage_root: ms_root)
      end
      let(:moab_validator) { complete_moab_handler.send(:moab_validator) }

      context 'there is no CompleteMoab' do
        let(:druid) { 'nd000lm0000' } # doesn't exist among fixtures on disk
        let(:incoming_version) { 3 }
        let!(:po) { create(:preserved_object, druid: druid, current_version: po_current_version, complete_moabs: []) }
        let!(:cm) { nil }

        it 'stops processing' do
          exp_str = "ActiveRecord::RecordNotFound: Couldn't find CompleteMoab.* db object does not exist"
          results = complete_moab_handler.confirm_version
          expect(results).to include(a_hash_including(AuditResults::DB_OBJ_DOES_NOT_EXIST => a_string_matching(exp_str)))
          expect(PreservedObject.find_by(druid: druid).current_version).to eq 2
        end
      end

      context "incoming and db versions match" do
        let(:incoming_version) { 2 }
        let(:incoming_size) { 1 }
        let(:version_matches_cm_msg) { "actual version (2) matches CompleteMoab db version" }

        context 'CompleteMoab' do
          context 'changed' do
            it 'last_version_audit' do
              expect { complete_moab_handler.confirm_version }.to change { complete_moab_handler.complete_moab.last_version_audit }
            end

            it 'updated_at' do
              expect { complete_moab_handler.confirm_version }.to change { complete_moab_handler.complete_moab.reload.updated_at }
            end
          end

          context 'unchanged' do
            it 'status' do
              expect { complete_moab_handler.confirm_version }.not_to change { complete_moab_handler.complete_moab.status }
            end

            it 'version' do
              expect { complete_moab_handler.confirm_version }.not_to change { complete_moab_handler.complete_moab.version }
            end

            it 'size' do
              expect { complete_moab_handler.confirm_version }.not_to change { complete_moab_handler.complete_moab.size }
            end

            it 'last_moab_validation' do
              expect { complete_moab_handler.confirm_version }.not_to change { complete_moab_handler.complete_moab.last_moab_validation }
            end
          end
        end

        it 'PreservedObject is not updated' do
          orig_timestamp = po.updated_at
          complete_moab_handler.confirm_version
          expect(po.reload.updated_at).to eq orig_timestamp
        end

        it_behaves_like 'calls AuditResults.report_results', :confirm_version
        context 'returns' do
          let(:results) { complete_moab_handler.confirm_version }

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

          before { allow(moab_validator).to receive(:moab_validation_errors).and_return([]) }

          it 'had OK_STATUS, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
            cm.ok!
            complete_moab_handler.confirm_version
            expect(cm.reload.status).to eq 'unexpected_version_on_storage'
          end

          it 'had INVALID_MOAB_STATUS, structure seems to be remediated, but is now UNEXPECTED_VERSION_ON_STORAGE_STATUS' do
            cm.invalid_moab!
            allow(moab_validator).to receive(:moab_validation_errors).and_return([])
            complete_moab_handler.confirm_version
            expect(cm.reload.status).to eq 'unexpected_version_on_storage'
          end
        end
      end

      context 'incoming version does NOT match db version' do
        let(:druid) { 'bj102hs9687' } # for shared_examples 'calls AuditResults.report_results', exists among fixtures on disk
        let(:ms_root) { MoabStorageRoot.find_by!(storage_location: 'spec/fixtures/storage_root01/sdr2objects') } # bj102hs9687's storage root
        let(:incoming_version) { 1 }
        let(:incoming_size) { 666 }

        it_behaves_like 'calls AuditResults.report_results', :confirm_version

        context '' do
          before { allow(moab_validator).to receive(:moab_validation_errors).and_return([]) }
          # Note this context cannot work with shared_examples 'calls AuditResults.report_results

          context 'CompleteMoab' do
            context 'changed' do
              it 'status to unexpected_version_on_storage' do
                expect(cm.status).to eq 'ok'
                complete_moab_handler.confirm_version
                expect(cm.reload.status).to eq 'unexpected_version_on_storage'
              end

              it 'last_version_audit' do
                orig = Time.current
                cm.last_version_audit = orig
                cm.save!
                complete_moab_handler.confirm_version
                expect(cm.reload.last_version_audit).to be > orig
              end

              it 'updated_at' do
                orig = cm.updated_at
                complete_moab_handler.confirm_version
                expect(cm.reload.updated_at).to be > orig
              end
            end

            context 'unchanged' do
              it 'version' do
                orig = cm.version
                complete_moab_handler.confirm_version
                expect(cm.reload.version).to eq orig
              end

              it 'size' do
                orig = cm.size
                complete_moab_handler.confirm_version
                expect(cm.reload.size).to eq orig
              end

              it 'last_moab_validation' do
                orig = cm.last_moab_validation
                complete_moab_handler.confirm_version
                expect(cm.reload.last_moab_validation).to eq orig
              end
            end
          end

          it 'PreservedObject is not updated' do
            orig_timestamp = po.updated_at
            complete_moab_handler.confirm_version
            expect(po.reload.updated_at).to eq orig_timestamp
          end

          context 'returns' do
            let!(:results) { complete_moab_handler.confirm_version }

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
        let(:druid) { 'bj102hs9687' } # for shared_examples 'calls AuditResults.report_results', exists among fixtures on disk
        let(:ms_root) { MoabStorageRoot.find_by!(storage_location: 'spec/fixtures/storage_root01/sdr2objects') } # bj102hs9687's storage root
        let(:po_current_version) { 8 }
        let(:cm_version) { 9 }

        it_behaves_like 'PreservedObject current_version does not match online CM version', :confirm_version, 6, 9, 8
      end

      context 'db update error (ActiveRecordError)' do
        let(:result_code) { AuditResults::DB_UPDATE_FAILED }
        let(:incoming_version) { 2 }
        let(:po) { create(:preserved_object, druid: druid, current_version: po_current_version) }

        before do
          allow(moab_validator).to receive(:moab_validation_errors).and_return([])
          allow(moab_validator.complete_moab).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
        end

        it 'DB_UPDATE_FAILED error' do
          expect(complete_moab_handler.confirm_version).to include(a_hash_including(AuditResults::DB_UPDATE_FAILED))
        end
      end

      describe 'calls CompleteMoab.save! (but not PreservedObject.save!)' do

        it 'if the existing record is altered' do
          allow(moab_validator).to receive(:moab_validation_errors).and_return([])
          expect(moab_validator.complete_moab).to receive(:save!)
          expect(moab_validator.complete_moab.preserved_object).not_to receive(:save!)
          complete_moab_handler.confirm_version
        end

        context '' do
          let(:incoming_version) { 1 }
          let(:incoming_size) { 1 }

          it 'calls CompleteMoab.save! (but not PreservedObject.save!) if the existing record is NOT altered' do
            allow(moab_validator).to receive(:moab_validation_errors).and_return([]) # different complete_moab_handler now
            expect(moab_validator.complete_moab).to receive(:save!)
            expect(moab_validator.complete_moab.preserved_object).not_to receive(:save!)
            complete_moab_handler.confirm_version
          end
        end
      end

      it 'logs a debug message' do
        allow(Rails.logger).to receive(:debug)
        expect(Rails.logger).to receive(:debug).with("confirm_version #{druid} called")
        allow(moab_validator).to receive(:moab_validation_errors).and_return([])
        complete_moab_handler.confirm_version
      end
    end

    it_behaves_like 'druid not in catalog', :confirm_version

    context 'there is no CompleteMoab for the PreservedObject' do
      let(:druid) { 'ab123cd4567' } # doesn't exist among fixtures on disk

      before { create(:preserved_object, druid: druid, complete_moabs: []) }

      it_behaves_like 'CompleteMoab does not exist', :confirm_version
    end
  end
end
