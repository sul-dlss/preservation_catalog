# frozen_string_literal: true

require 'rails_helper'
require 'services/complete_moab_service/shared_examples'

RSpec.describe CompleteMoabService::UpdateVersion do
  let(:audit_workflow_reporter) { instance_double(Reporters::AuditWorkflowReporter, report_errors: nil, report_completed: nil) }
  let(:db_update_failed_prefix) { 'db update failed' }
  let(:default_prez_policy) { PreservationPolicy.default_policy }
  let(:druid) { 'ab123cd4567' }
  let(:incoming_size) { 9876 }
  let(:incoming_version) { 6 }
  let(:ms_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  let(:po) { PreservedObject.find_by(druid: druid) }
  let(:cm) { complete_moab_handler.complete_moab }
  let(:complete_moab_handler) do
    described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size, moab_storage_root: ms_root)
  end
  let(:logger_reporter) { instance_double(Reporters::LoggerReporter, report_errors: nil, report_completed: nil) }
  let(:honeybadger_reporter) { instance_double(Reporters::HoneybadgerReporter, report_errors: nil, report_completed: nil) }
  let(:event_service_reporter) { instance_double(Reporters::EventServiceReporter, report_errors: nil, report_completed: nil) }

  before do
    allow(Reporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
    allow(Reporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
    allow(Reporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(Reporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
  end

  describe '#execute' do
    it_behaves_like 'attributes validated'

    context 'in Catalog' do
      before do
        create(:preserved_object, druid: druid, current_version: 2, preservation_policy: default_prez_policy)
        po.create_complete_moab!(
          version: po.current_version,
          size: 1,
          moab_storage_root: ms_root,
          status: 'ok', # pretending we checked for moab validation errs at create time
          last_version_audit: Time.current,
          last_moab_validation: Time.current
        ) do |primary_cm|
          PreservedObjectsPrimaryMoab.create!(preserved_object: po, complete_moab: primary_cm)
        end
      end

      context 'incoming version newer than catalog versions (both) (happy path)' do
        context 'CompleteMoab' do
          context 'changed' do
            it 'version becomes incoming_version' do
              expect { complete_moab_handler.execute }.to change(cm, :version).to be(incoming_version)
            end

            it 'last_version_audit' do
              expect { complete_moab_handler.execute }.to change(cm, :last_version_audit)
            end

            it 'size if supplied' do
              expect { complete_moab_handler.execute }.to change(cm, :size)
            end
          end

          context 'unchanged' do
            it 'size if incoming size is nil' do
              complete_moab_handler = described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: nil,
                                                          moab_storage_root: ms_root)
              expect { complete_moab_handler.execute }.not_to change { complete_moab_handler.complete_moab.size }
            end

            it 'last_moab_validation' do
              expect { complete_moab_handler.execute }.not_to change(cm, :last_moab_validation)
            end
          end

          context 'status' do
            context 'checksums_validated = false' do
              it 'starting status validity_unknown unchanged' do
                cm.update!(status: 'validity_unknown')
                expect { complete_moab_handler.execute }.not_to change(cm, :status).from('validity_unknown')
              end

              context 'starting status not validity_unknown' do
                shared_examples 'CMH#update_version changes status to "validity_unknown"' do |orig_status|
                  before { cm.update!(status: orig_status) }

                  it "original status #{orig_status}" do
                    expect { complete_moab_handler.execute }.to change(cm, :status)
                      .from(orig_status).to('validity_unknown')
                  end
                end

                it_behaves_like 'CMH#update_version changes status to "validity_unknown"', 'ok'
                it_behaves_like 'CMH#update_version changes status to "validity_unknown"', 'invalid_moab'
                it_behaves_like 'CMH#update_version changes status to "validity_unknown"', 'invalid_checksum'
                it_behaves_like 'CMH#update_version changes status to "validity_unknown"', 'online_moab_not_found'
                it_behaves_like 'CMH#update_version changes status to "validity_unknown"', 'unexpected_version_on_storage'
              end
            end

            context 'checksums_validated = true' do
              it 'starting status ok unchanged' do
                expect { complete_moab_handler.execute(checksums_validated: true) }.not_to change(cm, :status).from('ok')
              end

              context 'original status was not ok' do
                shared_examples 'CMH#update_version(true) does not change status' do |orig_status|
                  before { cm.update!(status: orig_status) }

                  it "original status #{orig_status}" do
                    expect { complete_moab_handler.execute(checksums_validated: true) }.not_to change(cm, :status)
                  end
                end

                it_behaves_like 'CMH#update_version(true) does not change status', 'validity_unknown'
                it_behaves_like 'CMH#update_version(true) does not change status', 'invalid_moab'
                it_behaves_like 'CMH#update_version(true) does not change status', 'invalid_checksum'
                # TODO: do these statuses change?
                it_behaves_like 'CMH#update_version(true) does not change status', 'online_moab_not_found'
                it_behaves_like 'CMH#update_version(true) does not change status', 'unexpected_version_on_storage'
              end
            end
          end
        end

        context 'calls #update_online_version with' do
          it 'status = "validity_unknown" for checksums_validated = false' do
            expect(complete_moab_handler).to receive(:update_online_version).with(status: 'validity_unknown', set_status_to_unexp_version: true,
                                                                                  checksums_validated: false).and_call_original
            complete_moab_handler.execute
            skip 'test is weak b/c we only indirectly show the effects of #update_online_version in #update_version specs'
          end

          it 'status = "ok" and checksums_validated = true for checksums_validated = true' do
            expect(complete_moab_handler).to receive(:update_online_version).with(status: nil, set_status_to_unexp_version: true,
                                                                                  checksums_validated: true).and_call_original
            complete_moab_handler.execute(checksums_validated: true)
            skip 'test is weak b/c we only indirectly show the effects of #update_online_version in #update_version specs'
          end
        end

        context 'PreservedObject changed' do
          it 'current_version becomes incoming version' do
            expect { complete_moab_handler.execute }.to change(complete_moab_handler.pres_object, :current_version)
              .to(incoming_version)
          end
        end

        it_behaves_like 'calls AuditResultsReporter.report_results'

        context 'returns' do
          let!(:results) { complete_moab_handler.execute(checksums_validated: true).results }

          it '1 results' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 1
          end

          it 'ACTUAL_VERS_GT_DB_OBJ results' do
            code = AuditResults::ACTUAL_VERS_GT_DB_OBJ
            version_gt_cm_msg = "actual version (#{incoming_version}) greater than CompleteMoab db version (2)"
            expect(results).to include(a_hash_including(code => version_gt_cm_msg))
          end
        end
      end

      context 'CompleteMoab and PreservedObject versions do not match' do
        before { cm.update(version: cm.version + 1) }

        it_behaves_like 'PreservedObject current_version does not match online CM version', 3, 3, 2
      end

      context 'incoming version same as catalog versions (both)' do
        it_behaves_like 'unexpected version', 2, 'ok'
      end

      context 'incoming version lower than catalog versions (both)' do
        it_behaves_like 'unexpected version', 1
      end

      context 'db update error' do
        let(:result_code) { AuditResults::DB_UPDATE_FAILED }

        context 'CompleteMoab' do
          context 'ActiveRecordError' do
            let(:results) do
              allow(Rails.logger).to receive(:log)
              allow(complete_moab_handler).to receive(:pres_object).and_return(po)
              allow(complete_moab_handler).to receive(:complete_moab).and_return(cm)
              allow(cm).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
              complete_moab_handler.execute.results
            end

            context 'DB_UPDATE_FAILED error' do
              it 'prefix' do
                expect(results).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix)))
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

        context 'PreservedObject' do
          context 'ActiveRecordError' do
            let(:druid) { 'zy666xw4567' }
            let(:results) do
              allow(Rails.logger).to receive(:log)
              allow(complete_moab_handler).to receive(:pres_object).and_return(po)
              allow(po).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
              complete_moab_handler.execute.results
            end

            context 'DB_UPDATE_FAILED error' do
              it 'prefix' do
                expect(results).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix)))
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
      end

      it 'calls PreservedObject.save! and CompleteMoab.save! if the records are altered' do
        allow(complete_moab_handler).to receive(:pres_object).and_return(po)
        allow(complete_moab_handler.pres_object).to receive(:complete_moab).and_return(cm)
        expect(po).to receive(:save!)
        expect(cm).to receive(:save!)
        complete_moab_handler.execute
      end

      context '' do
        let(:complete_moab_handler) { described_class.new(druid: druid, incoming_version: 1, incoming_size: 1, moab_storage_root: ms_root) }

        it 'does not call PreservedObject.save when CompleteMoab only has timestamp updates' do
          allow(complete_moab_handler).to receive(:pres_object).and_return(po)
          allow(complete_moab_handler.pres_object).to receive(:complete_moab).and_return(cm)
          expect(cm).to receive(:save!)
          expect(po).not_to receive(:save!)
          complete_moab_handler.execute
        end
      end

      it 'logs a debug message' do
        allow(Rails.logger).to receive(:debug)
        complete_moab_handler.execute
        expect(Rails.logger).to have_received(:debug).with("update_version #{druid} called")
      end
    end

    it_behaves_like 'druid not in catalog'

    context 'only PreservedObject exists' do
      before { create(:preserved_object, druid: druid, complete_moab: nil) }

      it_behaves_like 'CompleteMoab does not exist'
    end
  end
end
