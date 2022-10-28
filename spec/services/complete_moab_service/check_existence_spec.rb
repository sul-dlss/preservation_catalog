# frozen_string_literal: true

require 'rails_helper'
require 'services/complete_moab_service/shared_examples'

RSpec.describe CompleteMoabService::CheckExistence do
  let(:audit_workflow_reporter) { instance_double(Reporters::AuditWorkflowReporter, report_errors: nil) }
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let(:preserved_object) { PreservedObject.find_by!(druid: druid) }
  let(:moab_storage_root) { MoabStorageRoot.find_by!(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  let(:complete_moab) { CompleteMoab.find_by!(moab_storage_root: moab_storage_root) }
  let(:db_update_failed_prefix) { 'db update failed' }
  let(:complete_moab_service) do
    described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: incoming_size, moab_storage_root: moab_storage_root)
  end

  let(:moab_validator) { complete_moab_service.send(:moab_validator) }
  let(:logger_reporter) { instance_double(Reporters::LoggerReporter, report_errors: nil) }
  let(:honeybadger_reporter) { instance_double(Reporters::HoneybadgerReporter, report_errors: nil) }
  let(:event_service_reporter) { instance_double(Reporters::EventServiceReporter, report_errors: nil) }

  before do
    allow(Reporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
    allow(Reporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
    allow(Reporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(Reporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
  end

  describe '#check_existence' do
    it_behaves_like 'attributes validated', :execute

    context 'druid in db' do
      let(:druid) { 'bj102hs9687' }

      before do
        create(:preserved_object, druid: druid, current_version: 2)
        preserved_object.create_complete_moab!(
          version: preserved_object.current_version,
          size: 1,
          moab_storage_root: moab_storage_root,
          status: 'ok' # NOTE: we are pretending we checked for moab validation errs
        ) do |primary_complete_moab|
          PreservedObjectsPrimaryMoab.create!(preserved_object: preserved_object, complete_moab: primary_complete_moab)
        end
      end

      context 'incoming and db versions match' do
        let(:complete_moab_service) { described_class.new(druid: druid, incoming_version: 2, incoming_size: 1, moab_storage_root: moab_storage_root) }
        let(:version_matches_complete_moab_msg) { 'actual version (2) matches CompleteMoab db version' }

        context 'CompleteMoab' do
          context 'changed' do
            it 'last_version_audit' do
              original_time = Time.current
              complete_moab.last_version_audit = original_time
              complete_moab.save!
              complete_moab_service.execute
              expect(complete_moab.reload.last_version_audit).to be > original_time
            end

            it 'updated_at' do
              original_time = complete_moab.updated_at
              complete_moab_service.execute
              expect(complete_moab.reload.updated_at).to be > original_time
            end
          end

          context 'unchanged' do
            it 'status' do
              original_time = complete_moab.status
              complete_moab_service.execute
              expect(complete_moab.reload.status).to eq original_time
            end

            it 'version' do
              original_time = complete_moab.version
              complete_moab_service.execute
              expect(complete_moab.reload.version).to eq original_time
            end

            it 'size' do
              original_time = complete_moab.size
              complete_moab_service.execute
              expect(complete_moab.reload.size).to eq original_time
            end

            it 'last_moab_validation' do
              original_time = complete_moab.last_moab_validation
              complete_moab_service.execute
              expect(complete_moab.reload.last_moab_validation).to eq original_time
            end
          end
        end

        it 'PreservedObject is not updated' do
          original_time = preserved_object.updated_at
          complete_moab_service.execute
          expect(preserved_object.reload.updated_at).to eq original_time
        end

        it_behaves_like 'calls AuditResultsReporter.report_results'
        it 'does not validate moab' do
          expect(moab_validator).not_to receive(:moab_validation_errors)
          complete_moab_service.execute
        end

        context 'returns' do
          let(:audit_result) { complete_moab_service.execute }
          let(:results) { audit_result.results }

          it '1 VERSION_MATCHES result' do
            expect(audit_result).to be_an_instance_of AuditResults
            expect(results.size).to eq 1
            expect(results).to include(a_hash_including(AuditResults::VERSION_MATCHES => version_matches_complete_moab_msg))
          end
        end
      end

      context 'incoming version > db version' do
        let(:version_gt_complete_moab_msg) { "actual version (#{incoming_version}) greater than CompleteMoab db version (2)" }

        it 'calls Stanford::StorageObjectValidator.validation_errors for moab' do
          storage_object_validator = instance_double(Stanford::StorageObjectValidator)
          expect(storage_object_validator).to receive(:validation_errors).and_return([])
          allow(Stanford::StorageObjectValidator).to receive(:new).and_return(storage_object_validator)
          complete_moab_service.execute
        end

        context 'when moab is valid' do
          before { allow(moab_validator).to receive(:moab_validation_errors).and_return([]) }

          context 'CompleteMoab' do
            context 'changed' do
              before { allow(moab_validator).to receive(:ran_moab_validation?).and_return(true) }

              it 'version to incoming_version' do
                original_time = complete_moab.version
                complete_moab_service.execute
                expect(complete_moab.reload.version).to be > original_time
                expect(complete_moab.reload.version).to eq incoming_version
              end

              it 'size if supplied' do
                expect { complete_moab_service.execute }.to change { complete_moab_service.complete_moab.size }.to(incoming_size)
              end

              it 'last_moab_validation' do
                complete_moab_service.complete_moab.last_moab_validation = Time.current
                complete_moab_service.complete_moab.save!
                expect { complete_moab_service.execute }.to change { complete_moab_service.complete_moab.last_moab_validation }
              end

              it 'last_version_audit' do
                complete_moab_service.complete_moab.last_version_audit = Time.current
                complete_moab_service.complete_moab.save!
                expect { complete_moab_service.execute }.to change { complete_moab_service.complete_moab.last_version_audit }
              end

              it 'updated_at' do
                original_time = complete_moab.updated_at
                complete_moab_service.execute
                expect(complete_moab.reload.updated_at).to be > original_time
              end

              it 'status becomes "ok" if it was invalid_moab (b/c after validation)' do
                complete_moab.invalid_moab!
                complete_moab_service.execute
                expect(complete_moab.reload.status).to eq 'validity_unknown'
              end
            end

            context 'unchanged' do
              it 'status if former status was ok' do
                complete_moab_service.complete_moab.ok!
                expect { complete_moab_service.execute }.not_to change { complete_moab_service.complete_moab.status }.from('ok')
              end

              it 'size if incoming size is nil' do
                original_size = complete_moab.size
                complete_moab_service = described_class.new(druid: druid, incoming_version: incoming_version, incoming_size: nil,
                                                            moab_storage_root: moab_storage_root)
                complete_moab_service.execute
                expect(complete_moab.reload.size).to eq original_size
              end
            end
          end

          context 'PreservedObject changed' do
            it 'current_version' do
              expect { complete_moab_service.execute }.to change { complete_moab_service.preserved_object.current_version }
                .to(incoming_version)
            end

            it 'dependent CompleteMoab also updated' do
              expect { complete_moab_service.execute }.to change { complete_moab_service.complete_moab.updated_at }
            end
          end

          it_behaves_like 'calls AuditResultsReporter.report_results'

          context 'returns' do
            let(:results) { complete_moab_service.execute.results }

            before { allow(moab_validator).to receive(:moab_validation_errors).and_return([]) }

            it 'ACTUAL_VERS_GT_DB_OBJ results' do
              expect(results).to be_an Array
              expect(results.size).to eq 1
              expect(results.first).to include(AuditResults::ACTUAL_VERS_GT_DB_OBJ => version_gt_complete_moab_msg)
            end
          end
        end

        context 'when moab is invalid' do
          let(:invalid_druid) { 'xx000xx0000' }
          let(:invalid_storage_dir) { 'spec/fixtures/bad_root01/bad_moab_storage_trunk' }
          let(:invalid_root) { MoabStorageRoot.find_by(storage_location: invalid_storage_dir) }
          let(:invalid_complete_moab_service) do
            described_class.new(druid: invalid_druid, incoming_version: incoming_version, incoming_size: incoming_size,
                                moab_storage_root: invalid_root)
          end
          let(:invalid_preserved_object) { PreservedObject.find_by(druid: invalid_druid) }
          let(:invalid_complete_moab) { CompleteMoab.find_by(preserved_object: invalid_preserved_object) }

          before do
            # add storage root with the invalid moab to the MoabStorageRoots table
            MoabStorageRoot.find_or_create_by!(name: 'bad_fixture_dir') do |moab_storage_root|
              moab_storage_root.storage_location = invalid_storage_dir
            end
            # these need to be in before loop so it happens before each context below
            invalid_preserved_object = create(:preserved_object, druid: invalid_druid, current_version: 2)
            t = Time.current
            invalid_preserved_object.create_complete_moab!(
              version: invalid_preserved_object.current_version,
              size: 1,
              moab_storage_root: invalid_root,
              status: 'ok', # NOTE: we are pretending we checked for moab validation errs
              last_version_audit: t,
              last_moab_validation: t
            )
          end

          context 'CompleteMoab' do
            context 'changed' do
              it 'last_version_audit' do
                original_last_version_audit = invalid_complete_moab.last_version_audit
                invalid_complete_moab_service.execute
                expect(invalid_complete_moab.reload.last_version_audit).to be > original_last_version_audit
              end

              it 'last_moab_validation' do
                original_last_moab_validation = invalid_complete_moab.last_moab_validation
                invalid_complete_moab_service.execute
                expect(invalid_complete_moab.reload.last_moab_validation).to be > original_last_moab_validation
              end

              it 'updated_at' do
                original_updated_at = invalid_complete_moab.updated_at
                invalid_complete_moab_service.execute
                expect(invalid_complete_moab.reload.updated_at).to be > original_updated_at
              end

              it 'ensures status becomes invalid_moab from ok' do
                invalid_complete_moab.ok!
                invalid_complete_moab_service.execute
                expect(invalid_complete_moab.reload.status).to eq 'invalid_moab'
              end

              it 'ensures status becomes invalid_moab from unexpected_version_on_storage' do
                invalid_complete_moab.unexpected_version_on_storage!
                invalid_complete_moab_service.execute
                expect(invalid_complete_moab.reload.status).to eq 'invalid_moab'
              end
            end

            context 'unchanged' do
              it 'version' do
                original_version = invalid_complete_moab.version
                invalid_complete_moab_service.execute
                expect(invalid_complete_moab.reload.version).to eq original_version
              end

              it 'size' do
                original_size = invalid_complete_moab.size
                invalid_complete_moab_service.execute
                expect(invalid_complete_moab.reload.size).to eq original_size
              end
            end
          end

          it 'PreservedObject is not updated' do
            original_updated_at = invalid_preserved_object.updated_at
            invalid_complete_moab_service.execute
            expect(invalid_preserved_object.reload.updated_at).to eq original_updated_at
          end

          it_behaves_like 'calls AuditResultsReporter.report_results'

          context 'returns' do
            let(:results) { invalid_complete_moab_service.execute.results }

            it '3 results' do
              expect(results).to be_an_instance_of Array
              expect(results.size).to eq 3
            end

            it 'ACTUAL_VERS_GT_DB_OBJ results' do
              code = AuditResults::ACTUAL_VERS_GT_DB_OBJ
              expect(results).to include(a_hash_including(code => version_gt_complete_moab_msg))
            end

            it 'INVALID_MOAB result' do
              expect(results).to include(a_hash_including(AuditResults::INVALID_MOAB))
            end
          end
        end
      end

      context 'incoming version < db version' do
        let(:druid) { 'bp628nk4868' }
        let(:moab_storage_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root02/sdr2objects') }

        it_behaves_like 'unexpected version with validation', :check_existence, 1, 'unexpected_version_on_storage'
      end

      context 'CompleteMoab already has a status other than OK_STATUS' do
        it_behaves_like 'CompleteMoab may have its status checked when incoming_version == complete_moab.version'

        it_behaves_like 'CompleteMoab may have its status checked when incoming_version < complete_moab.version'

        context 'incoming_version > db version' do
          let(:incoming_version) { complete_moab.version + 1 }

          before { allow(moab_validator).to receive(:moab_validation_errors).and_return([]) }

          it 'had OK_STATUS, version increased, should still have OK_STATUS' do
            complete_moab.ok!
            complete_moab_service.execute
            expect(complete_moab.reload.status).to eq 'ok'
          end

          it 'had INVALID_MOAB_STATUS, was remediated, should now have VALIDITY_UNKNOWN_STATUS' do
            complete_moab.invalid_moab!
            complete_moab_service.execute
            expect(complete_moab.reload.status).to eq 'validity_unknown'
          end

          it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, seems to have an acceptable version now' do
            complete_moab.unexpected_version_on_storage!
            complete_moab_service.execute
            expect(complete_moab.reload.status).to eq 'validity_unknown'
          end
        end
      end

      context 'CompleteMoab version does NOT match PreservedObject current_version (online Moab)' do
        before do
          preserved_object.current_version = 8
          preserved_object.save!
        end

        it_behaves_like 'PreservedObject current_version does not match online CM version', 3, 2, 8
      end

      context 'db update error' do
        context 'ActiveRecordError' do
          let(:incoming_version) { 2 }

          before do
            allow(complete_moab_service).to receive(:complete_moab).and_return(complete_moab)
            allow(complete_moab).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
          end

          context 'transaction is rolled back' do
            it 'CompleteMoab is not updated' do
              expect { complete_moab_service.execute }.not_to change { complete_moab.reload.updated_at }
            end

            it 'PreservedObject is not updated' do
              expect { complete_moab_service.execute }.not_to change { complete_moab_service.preserved_object.reload.updated_at }
            end
          end

          context 'DB_UPDATE_FAILED error' do
            let(:results) { complete_moab_service.execute.results }
            let(:result_code) { AuditResults::DB_UPDATE_FAILED }

            it 'returns expected message(s)' do
              expect(results).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix)))
              expect(results).to include(a_hash_including(result_code => a_string_matching('ActiveRecord::ActiveRecordError')))
              expect(results).to include(a_hash_including(result_code => a_string_matching('foo')))
            end
          end
        end
      end

      it 'calls CompleteMoab.save! (but not PreservedObject.save!) if the existing record is NOT altered' do
        druid = 'zy987xw6543'
        pres_obj = create(:preserved_object, druid: druid)
        comp_moab = create(:complete_moab, preserved_object: pres_obj, moab_storage_root: moab_storage_root)
        expect do
          described_class.new(druid: druid, incoming_version: 1,
                              incoming_size: 1, moab_storage_root: moab_storage_root).execute
        end.not_to change {
                     pres_obj.reload.updated_at
                   }
        expect do
          described_class.new(druid: druid, incoming_version: 1,
                              incoming_size: 1, moab_storage_root: moab_storage_root).execute
        end.to change {
                 comp_moab.reload.updated_at
               }
      end

      it 'logs a debug message' do
        allow(Rails.logger).to receive(:debug)
        allow(moab_validator).to receive(:moab_validation_errors).and_return([])
        complete_moab_service.execute
        expect(Rails.logger).to have_received(:debug).with("check_existence #{druid} called")
      end
    end

    context 'object not in db' do
      let(:exp_complete_moab_not_exist_msg) { 'CompleteMoab db object does not exist' }
      let(:exp_obj_created_msg) { 'added object to db as it did not exist' }

      context 'presume validity and test other common behavior' do
        before { allow(moab_validator).to receive(:moab_validation_errors).and_return([]) }

        # FIXME: if requirements change to a single message for "object does not exist" and "created object"
        #  then this will no longer be correct?
        # NOTE: this pertains to PreservedObject
        it_behaves_like 'druid not in catalog'

        # FIXME: if requirements change to a single message for "object does not exist" and "created object"
        #  then this will no longer be correct?
        context 'there is no CompleteMoab for the PreservedObject' do
          before { create(:preserved_object, druid: druid) }
          # but no associated CompleteMoab

          it_behaves_like 'CompleteMoab does not exist'
        end
      end

      context 'adds to catalog after validation' do
        let(:valid_druid) { 'bp628nk4868' }
        let(:storage_dir) { 'spec/fixtures/storage_root02/sdr2objects' }
        let(:moab_storage_root) { MoabStorageRoot.find_by(storage_location: storage_dir) }
        let(:incoming_version) { 2 }
        let(:complete_moab_service) do
          described_class.new(druid: valid_druid, incoming_version: incoming_version, incoming_size: incoming_size,
                              moab_storage_root: moab_storage_root)
        end

        it 'calls Stanford::StorageObjectValidator.validation_errors for moab' do
          storage_object_validator = instance_double(Stanford::StorageObjectValidator)
          expect(storage_object_validator).to receive(:validation_errors).and_return([])
          allow(Stanford::StorageObjectValidator).to receive(:new).and_return(storage_object_validator)
          complete_moab_service.execute
        end

        context 'moab is valid' do
          it 'PreservedObject created' do
            po_args = {
              druid: valid_druid,
              current_version: incoming_version,
              preservation_policy_id: PreservationPolicy.default_policy.id
            }
            complete_moab_service.execute
            expect(PreservedObject.where(po_args)).to exist
          end

          it 'CompleteMoab created' do
            complete_moab_service.execute
            new_complete_moab = CompleteMoab.find_by(version: incoming_version, size: incoming_size, moab_storage_root: moab_storage_root)
            expect(new_complete_moab).not_to be_nil
            expect(new_complete_moab.status).to eq 'validity_unknown'
          end

          it_behaves_like 'calls AuditResultsReporter.report_results'

          context 'returns' do
            let(:audit_result) { complete_moab_service.execute }
            let(:results) { audit_result.results }

            it 'returns 2 results including expected messages' do
              expect(audit_result).to be_an_instance_of AuditResults
              expect(results.size).to eq 2
              expect(results).to include(a_hash_including(AuditResults::DB_OBJ_DOES_NOT_EXIST => exp_complete_moab_not_exist_msg))
              expect(results).to include(a_hash_including(AuditResults::CREATED_NEW_OBJECT => exp_obj_created_msg))
            end
          end

          context 'db update error (ActiveRecordError)' do
            let(:results) do
              allow(Rails.logger).to receive(:log)
              preserved_object = instance_double(PreservedObject)
              allow(preserved_object).to receive(:create_complete_moab!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
              allow(PreservedObject).to receive(:create!).with(hash_including(druid: valid_druid)).and_return(preserved_object)
              complete_moab_service.execute.results
            end

            it 'transaction is rolled back' do
              expect(CompleteMoab.find_by(moab_storage_root: moab_storage_root)).to be_nil
              expect(PreservedObject.find_by(druid: valid_druid)).to be_nil
            end

            context 'DB_UPDATE_FAILED error' do
              let(:result_code) { AuditResults::DB_UPDATE_FAILED }

              it 'returns expected message(s)' do
                expect(results).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix)))
                expect(results).to include(a_hash_including(result_code => a_string_matching('ActiveRecord::ActiveRecordError')))
                expect(results).to include(a_hash_including(result_code => a_string_matching('foo')))
              end
            end
          end
        end

        context 'moab is invalid' do
          let(:storage_dir) { 'spec/fixtures/bad_root01/bad_moab_storage_trunk' }
          let(:moab_storage_root) { MoabStorageRoot.find_by(storage_location: storage_dir) }
          let(:invalid_druid) { 'xx000xx0000' }
          let(:complete_moab_service) do
            described_class.new(druid: invalid_druid, incoming_version: incoming_version, incoming_size: incoming_size,
                                moab_storage_root: moab_storage_root)
          end

          before do
            # add storage root with the invalid moab to the MoabStorageRoots table
            MoabStorageRoot.find_or_create_by!(name: 'bad_fixture_dir') do |msr|
              msr.storage_location = storage_dir
            end
          end

          it 'creates PreservedObject; CompleteMoab with "invalid_moab" status' do
            complete_moab_service.execute
            new_complete_moab = CompleteMoab.find_by(size: incoming_size, moab_storage_root: moab_storage_root, version: incoming_version)
            expect(new_complete_moab).to be_a(CompleteMoab)
            expect(new_complete_moab.status).to eq('invalid_moab')
            expect(new_complete_moab.preserved_object.druid).to eq(invalid_druid)
          end

          it_behaves_like 'calls AuditResultsReporter.report_results'

          context 'returns' do
            let(:audit_result) { complete_moab_service.execute }
            let(:results) { audit_result.results }

            it '3 results with expected messages' do
              exp_moab_errs_msg = 'Invalid Moab, validation errors: ["Missing directory: [\\"data\\", \\"manifests\\"] Version: v0001"]'
              expect(audit_result).to be_an_instance_of AuditResults
              expect(results.size).to eq 3
              expect(results).to include(a_hash_including(AuditResults::INVALID_MOAB => exp_moab_errs_msg))
              expect(results).to include(a_hash_including(AuditResults::DB_OBJ_DOES_NOT_EXIST => exp_complete_moab_not_exist_msg))
              expect(results).to include(a_hash_including(AuditResults::CREATED_NEW_OBJECT => exp_obj_created_msg))
            end
          end

          context 'db update error (ActiveRecordError)' do
            let(:result_code) { AuditResults::DB_UPDATE_FAILED }
            let(:results) do
              preserved_object = instance_double(PreservedObject)
              allow(preserved_object).to receive(:create_complete_moab!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
              allow(PreservedObject).to receive(:create!).with(hash_including(druid: invalid_druid)).and_return(preserved_object)
              complete_moab_service.execute.results
            end

            before { allow(Rails.logger).to receive(:log) }

            it 'transaction is rolled back' do
              expect(CompleteMoab.find_by(moab_storage_root: moab_storage_root)).to be_nil
              expect(PreservedObject.find_by(druid: invalid_druid)).to be_nil
            end

            it 'DB_UPDATE_FAILED error includes expected message(s)' do
              expect(results).to include(a_hash_including(result_code => a_string_matching(db_update_failed_prefix)))
              expect(results).to include(a_hash_including(result_code => a_string_matching('ActiveRecord::ActiveRecordError')))
              expect(results).to include(a_hash_including(result_code => a_string_matching('foo')))
            end
          end
        end
      end
    end
  end
end
