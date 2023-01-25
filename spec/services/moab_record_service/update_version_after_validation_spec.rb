# frozen_string_literal: true

require 'rails_helper'
require 'services/moab_record_service/shared_examples'

RSpec.describe MoabRecordService::UpdateVersionAfterValidation do
  let(:audit_workflow_reporter) { instance_double(AuditReporters::AuditWorkflowReporter, report_errors: nil, report_completed: nil) }
  let(:db_update_failed_prefix) { 'db update failed' }
  let(:druid) { 'ab123cd4567' }
  let(:incoming_size) { 9876 }
  let(:incoming_version) { 6 }
  let(:moab_storage_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  let(:preserved_object) { PreservedObject.find_by(druid: druid) }
  let(:moab_record) { moab_record_service.moab_record }
  let(:moab_record_service) do
    described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size, moab_storage_root: moab_storage_root)
  end
  let(:logger_reporter) { instance_double(AuditReporters::LoggerReporter, report_errors: nil, report_completed: nil) }
  let(:honeybadger_reporter) { instance_double(AuditReporters::HoneybadgerReporter, report_errors: nil, report_completed: nil) }
  let(:event_service_reporter) { instance_double(AuditReporters::EventServiceReporter, report_errors: nil, report_completed: nil) }

  before do
    allow(AuditReporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
    allow(AuditReporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
    allow(AuditReporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(AuditReporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
  end

  describe 'execute' do
    let(:druid) { 'bp628nk4868' }
    let(:moab_storage_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root02/sdr2objects') }

    it_behaves_like 'attributes validated'

    it 'calls Stanford::StorageObjectValidator.validation_errors for moab' do
      storage_object_validator = instance_double(Stanford::StorageObjectValidator)
      expect(storage_object_validator).to receive(:validation_errors).and_return([])
      allow(Stanford::StorageObjectValidator).to receive(:new).and_return(storage_object_validator)
      moab_record_service.execute
    end

    context 'in Catalog' do
      context 'when moab is valid' do
        before do
          time = Time.current
          preserved_object.create_moab_record!(
            version: preserved_object.current_version,
            size: 1,
            moab_storage_root: moab_storage_root,
            status: 'ok', # NOTE: pretending we checked for moab validation errs at create time
            last_version_audit: time,
            last_moab_validation: time
          )
        end

        let(:preserved_object) { PreservedObject.create!(druid: druid, current_version: 2) }
        let(:moab_record) { preserved_object.moab_record }

        context 'MoabRecord' do
          context 'changed' do
            it 'last_version_audit' do
              original_last_version_audit = moab_record.last_version_audit
              moab_record_service.execute
              expect(moab_record.reload.last_version_audit).to be > original_last_version_audit
            end

            it 'last_moab_validation' do
              original_last_moab_validation = moab_record.last_moab_validation
              moab_record_service.execute
              expect(moab_record.reload.last_moab_validation).to be > original_last_moab_validation
            end

            it 'version becomes incoming_version' do
              original_version = moab_record.version
              moab_record_service.execute
              expect(moab_record.reload.version).to be > original_version
              expect(moab_record.version).to eq incoming_version
            end

            it 'size if supplied' do
              original_size = moab_record.size
              moab_record_service.execute
              expect(moab_record.reload.size).to eq incoming_size
              expect(moab_record.size).not_to eq original_size
            end
          end

          context 'unchanged' do
            it 'size if incoming size is nil' do
              original_size = moab_record.size
              moab_record_service = described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: nil,
                                                        moab_storage_root: moab_storage_root)
              moab_record_service.execute
              expect(moab_record.reload.size).to eq original_size
            end
          end

          context 'status' do
            context 'checksums_validated = false' do
              it 'starting status validity_unknown unchanged' do
                moab_record.update(status: 'validity_unknown')
                expect do
                  moab_record_service.execute
                end.not_to change { moab_record.reload.status }.from('validity_unknown')
              end

              context 'starting status not validity_unknown' do
                shared_examples '#update_version_after_validation changes status to "validity_unknown"' do |orig_status|
                  before { moab_record.update(status: orig_status) }

                  it "original status #{orig_status}" do
                    expect do
                      moab_record_service.execute
                    end.to change { moab_record.reload.status }.from(orig_status).to('validity_unknown')
                  end
                end

                it_behaves_like '#update_version_after_validation changes status to "validity_unknown"', 'ok'
                it_behaves_like '#update_version_after_validation changes status to "validity_unknown"', 'invalid_moab'
                it_behaves_like '#update_version_after_validation changes status to "validity_unknown"', 'invalid_checksum'
                it_behaves_like '#update_version_after_validation changes status to "validity_unknown"', 'moab_on_storage_not_found'
                it_behaves_like '#update_version_after_validation changes status to "validity_unknown"', 'unexpected_version_on_storage'
              end
            end

            context 'checksums_validated = true' do
              it 'starting status ok unchanged' do
                expect do
                  moab_record_service.execute(checksums_validated: true)
                end.not_to change { moab_record.reload.status }.from('ok')
              end

              context 'starting status not ok' do
                shared_examples '#update_version_after_validation(true) changes status to "ok"' do |orig_status|
                  before { moab_record.update(status: orig_status) }

                  it "original status #{orig_status}" do
                    expect do
                      moab_record_service.execute(checksums_validated: true)
                    end.to change { moab_record.reload.status }.from(orig_status).to('ok')
                  end
                end

                it_behaves_like '#update_version_after_validation(true) changes status to "ok"', 'validity_unknown'
                it_behaves_like '#update_version_after_validation(true) changes status to "ok"', 'invalid_moab'
                it_behaves_like '#update_version_after_validation(true) changes status to "ok"', 'invalid_checksum'
                it_behaves_like '#update_version_after_validation(true) changes status to "ok"', 'moab_on_storage_not_found'
                it_behaves_like '#update_version_after_validation(true) changes status to "ok"', 'unexpected_version_on_storage'
              end
            end
          end
        end

        context 'PreservedObject' do
          context 'changed' do
            it 'current_version' do
              orig = preserved_object.current_version
              moab_record_service.execute
              expect(preserved_object.reload.current_version).to eq moab_record_service.incoming_version
              expect(preserved_object.current_version).to be > orig
            end
          end
        end

        context 'calls #update_catalog with' do
          it 'status = "validity_unknown" for checksums_validated = false' do
            expect(moab_record_service).to receive(:update_catalog).with(status: 'validity_unknown',
                                                                         checksums_validated: false).and_call_original
            moab_record_service.execute(checksums_validated: false)
            skip 'test is weak b/c we only indirectly show the effects of #update_catalog in #update_version specs'
          end

          it 'status = "ok" and checksums_validated = true for checksums_validated = true' do
            expect(moab_record_service).to receive(:update_catalog).with(status: 'ok', checksums_validated: true).and_call_original
            moab_record_service.execute(checksums_validated: true)
            skip 'test is weak b/c we only indirectly show the effects of #update_catalog in #update_version specs'
          end
        end
      end

      context 'when moab is invalid' do
        let(:druid) { 'xx000xx0000' }
        let(:storage_dir) { 'spec/fixtures/bad_root01/bad_moab_storage_trunk' }
        let(:moab_storage_root) { MoabStorageRoot.find_by(storage_location: storage_dir) }

        before do
          MoabStorageRoot.find_or_create_by!(name: 'bad_fixture_dir') do |msr|
            msr.storage_location = storage_dir
          end
          preserved_object = PreservedObject.create!(druid: druid, current_version: 2)
          time = Time.current
          MoabRecord.create!(
            preserved_object: preserved_object,
            version: preserved_object.current_version,
            size: 1,
            moab_storage_root: moab_storage_root,
            status: 'ok', # pretending we checked for moab validation errs at create time
            last_version_audit: time,
            last_moab_validation: time
          )
        end

        context 'checksums_validated = false' do
          context 'MoabRecord' do
            it 'last_moab_validation updated' do
              expect do
                moab_record_service.execute
              end.to change { moab_record.reload.status }.from('ok').to('validity_unknown')
            end

            it 'size updated to incoming_size' do
              expect do
                moab_record_service.execute
              end.to change { moab_record.reload.size }.to(incoming_size)
            end

            it 'last_version_audit updated' do
              expect do
                moab_record_service.execute
              end.to change { moab_record.reload.last_version_audit }
            end

            it 'version updated to incoming_version' do
              expect do
                moab_record_service.execute
              end.to change { moab_record.reload.version }.from(2).to(incoming_version)
            end

            context 'status' do
              it 'starting status validity_unknown unchanged' do
                moab_record.update(status: 'validity_unknown')
                expect do
                  moab_record_service.execute
                end.not_to change { moab_record.reload.status }.from('validity_unknown')
              end

              context 'starting status was not validity_unknown' do
                shared_examples '#update_version_after_validation changes status to "validity_unknown"' do |orig_status|
                  before { moab_record.update(status: orig_status) }

                  it "original status #{orig_status}" do
                    # (due to newer version not checksum validated)
                    expect do
                      moab_record_service.execute
                    end.to change { moab_record.reload.status }.from(orig_status).to('validity_unknown')
                  end
                end

                it_behaves_like '#update_version_after_validation changes status to "validity_unknown"', 'ok'
                it_behaves_like '#update_version_after_validation changes status to "validity_unknown"', 'moab_on_storage_not_found'
                it_behaves_like '#update_version_after_validation changes status to "validity_unknown"', 'unexpected_version_on_storage'
                it_behaves_like '#update_version_after_validation changes status to "validity_unknown"', 'invalid_moab'
                it_behaves_like '#update_version_after_validation changes status to "validity_unknown"', 'invalid_checksum'
              end
            end
          end
        end

        context 'checksums_validated = true' do
          context 'MoabRecord' do
            it 'last_moab_validation updated' do
              expect do
                moab_record_service.execute(checksums_validated: true)
              end.to change { moab_record.reload.last_moab_validation }
            end

            it 'size updated to incoming_size' do
              expect do
                moab_record_service.execute(checksums_validated: true)
              end.to change { moab_record.reload.size }.to(incoming_size)
            end

            it 'last_version_audit updated' do
              expect do
                moab_record_service.execute(checksums_validated: true)
              end.to change { moab_record.reload.last_version_audit }
            end

            it 'version updated to incoming_version' do
              expect do
                moab_record_service.execute(checksums_validated: true)
              end.to change { moab_record.reload.version }.from(2).to(incoming_version)
            end

            context 'status' do
              it 'starting status invalid_moab unchanged' do
                moab_record.update(status: 'invalid_moab')
                expect do
                  moab_record_service.execute(checksums_validated: true)
                end.not_to change { moab_record.reload.status }.from('invalid_moab')
              end

              context 'starting status was not invalid_moab' do
                shared_examples '#update_version_after_validation(true) changes status to "invalid_moab"' do |orig_status|
                  before { moab_record.update(status: orig_status) }

                  it "original status #{orig_status}" do
                    expect do
                      moab_record_service.execute(checksums_validated: true)
                    end.to change { moab_record.reload.status }.from(orig_status).to('invalid_moab')
                  end
                end

                it_behaves_like '#update_version_after_validation(true) changes status to "invalid_moab"', 'ok'
                it_behaves_like '#update_version_after_validation(true) changes status to "invalid_moab"', 'validity_unknown'
                it_behaves_like '#update_version_after_validation(true) changes status to "invalid_moab"', 'moab_on_storage_not_found'
                it_behaves_like '#update_version_after_validation(true) changes status to "invalid_moab"', 'unexpected_version_on_storage'
                it_behaves_like '#update_version_after_validation(true) changes status to "invalid_moab"', 'invalid_checksum'
              end
            end
          end
        end

        context 'PreservedObject' do
          context 'unchanged' do
            it 'current_version' do
              original_version = preserved_object.current_version
              moab_record_service.execute
              expect(preserved_object.current_version).to eq original_version
            end
          end
        end

        context 'calls #update_catalog with' do
          it 'status = "validity_unknown" for checksums_validated = false' do
            expect(moab_record_service).to receive(:update_catalog).with(status: 'validity_unknown').and_call_original
            moab_record_service.execute
            skip 'test is weak b/c we only indirectly show the effects of #update_catalog in #update_version specs'
          end

          it 'status = "invalid_moab" and checksums_validated = true for checksums_validated = true' do
            expect(moab_record_service).to receive(:update_catalog).with(status: 'invalid_moab', checksums_validated: true).and_call_original
            moab_record_service.execute(checksums_validated: true)
            skip 'test is weak b/c we only indirectly show the effects of #update_catalog in #update_version specs'
          end
        end

        it 'logs a debug message' do
          msg = "update_version_after_validation #{druid} called"
          allow(Rails.logger).to receive(:debug)
          moab_record_service.execute
          expect(Rails.logger).to have_received(:debug).with(msg)
        end

        context 'MoabRecord and PreservedObject versions do not match' do
          before do
            moab_record.version = moab_record.version + 1
            moab_record.save!
          end

          context 'checksums_validated = false' do
            context 'MoabRecord' do
              it 'last_moab_validation updated' do
                expect { moab_record_service.execute }.to change { moab_record.reload.last_moab_validation }
              end

              it 'last_version_audit unchanged' do
                expect { moab_record_service.execute }.not_to change { moab_record.reload.last_version_audit }
              end

              it 'size unchanged' do
                expect { moab_record_service.execute }.not_to change { moab_record.reload.size }
              end

              it 'version unchanged' do
                expect { moab_record_service.execute }.not_to change { moab_record.reload.version }
              end

              it 'status becomes validity_unknown (due to newer version not checksum validated)' do
                expect { moab_record_service.execute }.to change { moab_record.reload.status }.to('validity_unknown')
              end
            end

            it 'does not update PreservedObject' do
              expect { moab_record_service.execute }.not_to change { preserved_object.reload.updated_at }
            end

            context 'returns' do
              let!(:results) { moab_record_service.execute.results }

              it '3 results' do
                expect(results).to be_an_instance_of Array
                expect(results.size).to eq 3
              end

              it 'INVALID_MOAB result' do
                code = Audit::Results::INVALID_MOAB
                invalid_moab_msg = 'Invalid Moab, validation errors: ["Missing directory: [\\"data\\", \\"manifests\\"] Version: v0001"]'
                expect(results).to include(hash_including(code => invalid_moab_msg))
              end

              it 'DB_VERSIONS_DISAGREE result' do
                code = Audit::Results::DB_VERSIONS_DISAGREE
                mismatch_msg = 'MoabRecord version 3 does not match PreservedObject current_version 2'
                expect(results).to include(hash_including(code => mismatch_msg))
              end

              it 'MOAB_RECORD_STATUS_CHANGED result' do
                updated_status_msg_regex = Regexp.new('MoabRecord status changed from')
                expect(results).to include(a_hash_including(Audit::Results::MOAB_RECORD_STATUS_CHANGED => updated_status_msg_regex))
              end
            end
          end

          context 'checksums_validated = true' do
            context 'MoabRecord' do
              it 'last_moab_validation updated' do
                expect { moab_record_service.execute(checksums_validated: true) }.to change { moab_record.reload.last_moab_validation }
              end

              it 'last_version_audit unchanged' do
                expect { moab_record_service.execute(checksums_validated: true) }.not_to change { moab_record.reload.last_version_audit }
              end

              it 'size unchanged' do
                expect { moab_record_service.execute(checksums_validated: true) }.not_to change { moab_record.reload.size }
              end

              it 'version unchanged' do
                expect { moab_record_service.execute(checksums_validated: true) }.not_to change { moab_record.reload.version }
              end

              it 'status becomes invalid_moab' do
                expect { moab_record_service.execute(checksums_validated: true) }.to change { moab_record.reload.status }.to('invalid_moab')
              end
            end

            it 'does not update PreservedObject' do
              expect { moab_record_service.execute(checksums_validated: true) }.not_to change { preserved_object.reload.updated_at }
            end

            context 'returns' do
              let!(:results) { moab_record_service.execute(checksums_validated: true).results }

              it '3 results' do
                expect(results).to be_an_instance_of Array
                expect(results.size).to eq 3
              end

              it 'INVALID_MOAB result' do
                code = Audit::Results::INVALID_MOAB
                invalid_moab_msg = 'Invalid Moab, validation errors: ["Missing directory: [\\"data\\", \\"manifests\\"] Version: v0001"]'
                expect(results).to include(hash_including(code => invalid_moab_msg))
              end

              it 'DB_VERSIONS_DISAGREE result' do
                code = Audit::Results::DB_VERSIONS_DISAGREE
                mismatch_msg = 'MoabRecord version 3 does not match PreservedObject current_version 2'
                expect(results).to include(hash_including(code => mismatch_msg))
              end

              it 'MOAB_RECORD_STATUS_CHANGED result' do
                updated_status_msg_regex = Regexp.new('MoabRecord status changed from')
                expect(results).to include(a_hash_including(Audit::Results::MOAB_RECORD_STATUS_CHANGED => updated_status_msg_regex))
              end
            end
          end
        end

        context 'incoming version same as catalog versions (both)' do
          it_behaves_like 'unexpected version with validation', :update_version_after_validation, 2, 'invalid_moab'
        end

        context 'incoming version lower than catalog versions (both)' do
          it_behaves_like 'unexpected version with validation', :update_version_after_validation, 1, 'invalid_moab'
        end

        context 'db update error' do
          let(:result_code) { Audit::Results::DB_UPDATE_FAILED }

          context 'MoabRecord' do
            context 'ActiveRecordError' do
              let(:results) do
                allow(Rails.logger).to receive(:log)
                allow(moab_record_service).to receive(:preserved_object).and_return(preserved_object)
                allow(moab_record_service.preserved_object).to receive(:moab_record).and_return(moab_record)
                allow(moab_record).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
                moab_record_service.execute.results
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
          # PreservedObject won't get updated if moab is invalid
        end
      end
    end

    it_behaves_like 'druid not in catalog'

    context 'there is no MoabRecord for the PreservedObject' do
      before { create(:preserved_object, druid: druid, moab_record: nil) }

      it_behaves_like 'MoabRecord does not exist'
    end
  end
end
