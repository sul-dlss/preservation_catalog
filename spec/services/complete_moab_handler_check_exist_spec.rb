# frozen_string_literal: true

require 'rails_helper'
require 'services/shared_examples_complete_moab_handler'

RSpec.describe CompleteMoabHandler do
  let(:workflow_reporter) { instance_double(Reporters::WorkflowReporter, report_errors: nil) }
  let(:druid) { 'ab123cd4567' }
  let(:incoming_version) { 6 }
  let(:incoming_size) { 9876 }
  let(:po) { PreservedObject.find_by!(druid: druid) }
  let(:ms_root) { MoabStorageRoot.find_by!(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  # Adds new complete moab with the same druid to confirm that tests pass
  let(:cm) {
    create(:complete_moab, preserved_object: po)
    po.complete_moabs.find_by!(moab_storage_root: ms_root)
  }
  let(:db_update_failed_prefix) { 'db update failed' }
  let(:complete_moab_handler) { described_class.new(druid, incoming_version, incoming_size, ms_root) }
  let(:moab_validator) { complete_moab_handler.send(:moab_validator) }
  let(:logger_reporter) { instance_double(Reporters::LoggerReporter, report_errors: nil) }
  let(:honeybadger_reporter) { instance_double(Reporters::HoneybadgerReporter, report_errors: nil) }
  let(:event_service_reporter) { instance_double(Reporters::EventServiceReporter, report_errors: nil) }

  before do
    allow(Reporters::WorkflowReporter).to receive(:new).and_return(workflow_reporter)
    allow(Reporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
    allow(Reporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(Reporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
  end

  describe '#check_existence' do
    it_behaves_like 'attributes validated', :check_existence

    context 'druid in db' do
      let(:druid) { 'bj102hs9687' }

      before do
        create(:preserved_object, druid: druid, current_version: 2)
        po.complete_moabs.create!(
          version: po.current_version,
          size: 1,
          moab_storage_root: ms_root,
          status: 'ok' # NOTE: we are pretending we checked for moab validation errs
        ) do |primary_cm|
          PreservedObjectsPrimaryMoab.create!(preserved_object: po, complete_moab: primary_cm)
        end
      end

      context 'incoming and db versions match' do
        let(:complete_moab_handler) { described_class.new(druid, 2, 1, ms_root) }
        let(:version_matches_cm_msg) { 'actual version (2) matches CompleteMoab db version' }

        context 'CompleteMoab' do
          context 'changed' do
            it 'last_version_audit' do
              orig = Time.current
              cm.last_version_audit = orig
              cm.save!
              complete_moab_handler.check_existence
              expect(cm.reload.last_version_audit).to be > orig
            end

            it 'updated_at' do
              orig = cm.updated_at
              complete_moab_handler.check_existence
              expect(cm.reload.updated_at).to be > orig
            end
          end

          context 'unchanged' do
            it 'status' do
              orig = cm.status
              complete_moab_handler.check_existence
              expect(cm.reload.status).to eq orig
            end

            it 'version' do
              orig = cm.version
              complete_moab_handler.check_existence
              expect(cm.reload.version).to eq orig
            end

            it 'size' do
              orig = cm.size
              complete_moab_handler.check_existence
              expect(cm.reload.size).to eq orig
            end

            it 'last_moab_validation' do
              orig = cm.last_moab_validation
              complete_moab_handler.check_existence
              expect(cm.reload.last_moab_validation).to eq orig
            end
          end
        end

        it 'PreservedObject is not updated' do
          orig = po.updated_at
          complete_moab_handler.check_existence
          expect(po.reload.updated_at).to eq orig
        end

        it_behaves_like 'calls AuditResults.report_results', :check_existence
        it 'does not validate moab' do
          expect(moab_validator).not_to receive(:moab_validation_errors)
          complete_moab_handler.check_existence
        end

        context 'returns' do
          let(:results) { complete_moab_handler.check_existence }

          it '1 VERSION_MATCHES result' do
            expect(results).to be_an_instance_of Array
            expect(results.size).to eq 1
            expect(results).to include(a_hash_including(AuditResults::VERSION_MATCHES => version_matches_cm_msg))
          end
        end
      end

      context 'incoming version > db version' do
        let(:version_gt_cm_msg) { "actual version (#{incoming_version}) greater than CompleteMoab db version (2)" }

        it 'calls Stanford::StorageObjectValidator.validation_errors for moab' do
          mock_sov = instance_double(Stanford::StorageObjectValidator)
          expect(mock_sov).to receive(:validation_errors).and_return([])
          allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
          complete_moab_handler.check_existence
        end

        context 'when moab is valid' do
          before { allow(moab_validator).to receive(:moab_validation_errors).and_return([]) }

          context 'CompleteMoab' do
            context 'changed' do
              before { allow(complete_moab_handler).to receive(:ran_moab_validation?).and_return(true) }

              it 'version to incoming_version' do
                orig = cm.version
                complete_moab_handler.check_existence
                expect(cm.reload.version).to be > orig
                expect(cm.reload.version).to eq incoming_version
              end

              it 'size if supplied' do
                expect { complete_moab_handler.check_existence }.to change { complete_moab_handler.complete_moab.size }.to(incoming_size)
              end

              it 'last_moab_validation' do
                complete_moab_handler.complete_moab.last_moab_validation = Time.current
                complete_moab_handler.complete_moab.save!
                expect { complete_moab_handler.check_existence }.to change { complete_moab_handler.complete_moab.last_moab_validation }
              end

              it 'last_version_audit' do
                complete_moab_handler.complete_moab.last_version_audit = Time.current
                complete_moab_handler.complete_moab.save!
                expect { complete_moab_handler.check_existence }.to change { complete_moab_handler.complete_moab.last_version_audit }
              end

              it 'updated_at' do
                orig = cm.updated_at
                complete_moab_handler.check_existence
                expect(cm.reload.updated_at).to be > orig
              end

              it 'status becomes "ok" if it was invalid_moab (b/c after validation)' do
                cm.invalid_moab!
                complete_moab_handler.check_existence
                expect(cm.reload.status).to eq 'validity_unknown'
              end
            end

            context 'unchanged' do
              it 'status if former status was ok' do
                complete_moab_handler.complete_moab.ok!
                expect { complete_moab_handler.check_existence }.not_to change { complete_moab_handler.complete_moab.status }.from('ok')
              end

              it 'size if incoming size is nil' do
                orig = cm.size
                complete_moab_handler = described_class.new(druid, incoming_version, nil, ms_root)
                complete_moab_handler.check_existence
                expect(cm.reload.size).to eq orig
              end
            end
          end

          context 'PreservedObject changed' do
            it 'current_version' do
              expect { complete_moab_handler.check_existence }.to change { complete_moab_handler.pres_object.current_version }
                .to(incoming_version)
            end

            it 'dependent CompleteMoab also updated' do
              expect { complete_moab_handler.check_existence }.to change { complete_moab_handler.complete_moab.updated_at }
            end
          end

          it_behaves_like 'calls AuditResults.report_results', :check_existence

          context 'returns' do
            let(:results) { complete_moab_handler.check_existence }

            before { allow(moab_validator).to receive(:moab_validation_errors).and_return([]) }

            it 'ACTUAL_VERS_GT_DB_OBJ results' do
              expect(results).to be_an Array
              expect(results.size).to eq 1
              expect(results.first).to include(AuditResults::ACTUAL_VERS_GT_DB_OBJ => version_gt_cm_msg)
            end
          end
        end

        context 'when moab is invalid' do
          let(:invalid_druid) { 'xx000xx0000' }
          let(:invalid_storage_dir) { 'spec/fixtures/bad_root01/bad_moab_storage_trunk' }
          let(:invalid_root) { MoabStorageRoot.find_by(storage_location: invalid_storage_dir) }
          let(:invalid_complete_moab_handler) { described_class.new(invalid_druid, incoming_version, incoming_size, invalid_root) }
          let(:invalid_po) { PreservedObject.find_by(druid: invalid_druid) }
          let(:invalid_cm) { CompleteMoab.find_by(preserved_object: invalid_po) }

          before do
            # add storage root with the invalid moab to the MoabStorageRoots table
            MoabStorageRoot.find_or_create_by!(name: 'bad_fixture_dir') do |msr|
              msr.storage_location = invalid_storage_dir
            end
            # these need to be in before loop so it happens before each context below
            invalid_po = create(:preserved_object, druid: invalid_druid, current_version: 2)
            t = Time.current
            invalid_po.complete_moabs.create!(
              version: invalid_po.current_version,
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
                orig = invalid_cm.last_version_audit
                invalid_complete_moab_handler.check_existence
                expect(invalid_cm.reload.last_version_audit).to be > orig
              end

              it 'last_moab_validation' do
                orig = invalid_cm.last_moab_validation
                invalid_complete_moab_handler.check_existence
                expect(invalid_cm.reload.last_moab_validation).to be > orig
              end

              it 'updated_at' do
                orig = invalid_cm.updated_at
                invalid_complete_moab_handler.check_existence
                expect(invalid_cm.reload.updated_at).to be > orig
              end

              it 'ensures status becomes invalid_moab from ok' do
                invalid_cm.ok!
                invalid_complete_moab_handler.check_existence
                expect(invalid_cm.reload.status).to eq 'invalid_moab'
              end

              it 'ensures status becomes invalid_moab from unexpected_version_on_storage' do
                invalid_cm.unexpected_version_on_storage!
                invalid_complete_moab_handler.check_existence
                expect(invalid_cm.reload.status).to eq 'invalid_moab'
              end
            end

            context 'unchanged' do
              it 'version' do
                orig = invalid_cm.version
                invalid_complete_moab_handler.check_existence
                expect(invalid_cm.reload.version).to eq orig
              end

              it 'size' do
                orig = invalid_cm.size
                invalid_complete_moab_handler.check_existence
                expect(invalid_cm.reload.size).to eq orig
              end
            end
          end

          it 'PreservedObject is not updated' do
            orig_timestamp = invalid_po.updated_at
            invalid_complete_moab_handler.check_existence
            expect(invalid_po.reload.updated_at).to eq orig_timestamp
          end

          it_behaves_like 'calls AuditResults.report_results', :check_existence

          context 'returns' do
            let(:results) { invalid_complete_moab_handler.check_existence }

            it '3 results' do
              expect(results).to be_an_instance_of Array
              expect(results.size).to eq 3
            end

            it 'ACTUAL_VERS_GT_DB_OBJ results' do
              code = AuditResults::ACTUAL_VERS_GT_DB_OBJ
              expect(results).to include(a_hash_including(code => version_gt_cm_msg))
            end

            it 'INVALID_MOAB result' do
              expect(results).to include(a_hash_including(AuditResults::INVALID_MOAB))
            end
          end
        end
      end

      context 'incoming version < db version' do
        let(:druid) { 'bp628nk4868' }
        let(:ms_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root02/sdr2objects') }

        it_behaves_like 'unexpected version with validation', :check_existence, 1, 'unexpected_version_on_storage'
      end

      context 'CompleteMoab already has a status other than OK_STATUS' do
        it_behaves_like 'CompleteMoab may have its status checked when incoming_version == cm.version', :check_existence

        it_behaves_like 'CompleteMoab may have its status checked when incoming_version < cm.version', :check_existence

        context 'incoming_version > db version' do
          let(:incoming_version) { cm.version + 1 }

          before { allow(moab_validator).to receive(:moab_validation_errors).and_return([]) }

          it 'had OK_STATUS, version increased, should still have OK_STATUS' do
            cm.ok!
            complete_moab_handler.check_existence
            expect(cm.reload.status).to eq 'ok'
          end

          it 'had INVALID_MOAB_STATUS, was remediated, should now have VALIDITY_UNKNOWN_STATUS' do
            cm.invalid_moab!
            complete_moab_handler.check_existence
            expect(cm.reload.status).to eq 'validity_unknown'
          end

          it 'had UNEXPECTED_VERSION_ON_STORAGE_STATUS, seems to have an acceptable version now' do
            cm.unexpected_version_on_storage!
            complete_moab_handler.check_existence
            expect(cm.reload.status).to eq 'validity_unknown'
          end
        end
      end

      context 'CompleteMoab version does NOT match PreservedObject current_version (online Moab)' do
        before do
          po.current_version = 8
          po.save!
        end

        it_behaves_like 'PreservedObject current_version does not match online CM version', :check_existence, 3, 2, 8
      end

      context 'db update error' do
        context 'ActiveRecordError' do
          let(:incoming_version) { 2 }

          before do
            allow(moab_validator.complete_moab).to receive(:save!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
          end

          context 'transaction is rolled back' do
            it 'CompleteMoab is not updated' do
              expect { complete_moab_handler.check_existence }.not_to change { complete_moab_handler.complete_moab.reload.updated_at }
            end

            it 'PreservedObject is not updated' do
              expect { complete_moab_handler.check_existence }.not_to change { complete_moab_handler.pres_object.reload.updated_at }
            end
          end

          context 'DB_UPDATE_FAILED error' do
            let(:results) { complete_moab_handler.check_existence }
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
        comp_moab = create(:complete_moab, preserved_object: pres_obj, moab_storage_root: ms_root)
        expect { described_class.new(druid, 1, 1, ms_root).check_existence }.not_to change { pres_obj.reload.updated_at }
        expect { described_class.new(druid, 1, 1, ms_root).check_existence }.to change { comp_moab.reload.updated_at }
      end

      it 'logs a debug message' do
        allow(Rails.logger).to receive(:debug)
        allow(moab_validator).to receive(:moab_validation_errors).and_return([])
        complete_moab_handler.check_existence
        expect(Rails.logger).to have_received(:debug).with("check_existence #{druid} called")
      end
    end

    context 'object not in db' do
      let(:exp_cm_not_exist_msg) { 'CompleteMoab db object does not exist' }
      let(:exp_obj_created_msg) { 'added object to db as it did not exist' }

      context 'presume validity and test other common behavior' do
        before { allow(moab_validator).to receive(:moab_validation_errors).and_return([]) }

        # FIXME: if requirements change to a single message for "object does not exist" and "created object"
        #  then this will no longer be correct?
        # NOTE: this pertains to PreservedObject
        it_behaves_like 'druid not in catalog', :check_existence

        # FIXME: if requirements change to a single message for "object does not exist" and "created object"
        #  then this will no longer be correct?
        context 'there is no CompleteMoab for the PreservedObject' do
          before { create(:preserved_object, druid: druid) }
          # but no associated CompleteMoab

          it_behaves_like 'CompleteMoab does not exist', :check_existence
        end
      end

      context 'there are two moabs for the druid' do
        let(:druid) { 'bz514sm9647' }
        let(:msr_1) { MoabStorageRoot.find_by!(name: 'fixture_sr1') }
        let(:msr_a) { MoabStorageRoot.find_by!(name: 'fixture_srA') }
        let(:cm_1) { CompleteMoab.by_druid(druid).find_by!(moab_storage_root: msr_1) }
        let(:cm_a) { CompleteMoab.by_druid(druid).find_by!(moab_storage_root: msr_a) }

        context 'the one with the lower version is the primary' do
          before do
            described_class.new(druid, 3, 356, msr_1).check_existence # first added is primary by default
            described_class.new(druid, 1, 232, msr_a).check_existence
          end

          it 'sets CompleteMoab#version to the version of the moab on that storage root' do
            expect(cm_1.version).to eq 3
            expect(cm_a.version).to eq 1
          end

          it 'sets PreservedObject#current_version to the highest version seen for the primary CompleteMoab' do
            expect(po.current_version).to eq 3
          end
        end

        context 'the one with the higher version is the primary' do
          before do
            described_class.new(druid, 1, 232, msr_a).check_existence # first added is primary by default
            described_class.new(druid, 3, 356, msr_1).check_existence
          end

          it 'sets CompleteMoab#version to the version of the moab on that storage root' do
            expect(cm_1.version).to eq 3
            expect(cm_a.version).to eq 1
          end

          it 'sets PreservedObject#current_version to the highest version seen for the primary CompleteMoab' do
            expect(po.current_version).to eq 1 # the copy that's behind is the primary -- this would be unusual, but just to define the behavior
          end
        end
      end

      context 'adds to catalog after validation' do
        let(:valid_druid) { 'bp628nk4868' }
        let(:storage_dir) { 'spec/fixtures/storage_root02/sdr2objects' }
        let(:ms_root) { MoabStorageRoot.find_by(storage_location: storage_dir) }
        let(:incoming_version) { 2 }
        let(:complete_moab_handler) { described_class.new(valid_druid, incoming_version, incoming_size, ms_root) }

        it 'calls Stanford::StorageObjectValidator.validation_errors for moab' do
          mock_sov = instance_double(Stanford::StorageObjectValidator)
          expect(mock_sov).to receive(:validation_errors).and_return([])
          allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
          complete_moab_handler.check_existence
        end

        context 'moab is valid' do
          it 'PreservedObject created' do
            po_args = {
              druid: valid_druid,
              current_version: incoming_version,
              preservation_policy_id: PreservationPolicy.default_policy.id
            }
            complete_moab_handler.check_existence
            expect(PreservedObject.where(po_args)).to exist
          end

          it 'CompleteMoab created' do
            complete_moab_handler.check_existence
            new_cm = CompleteMoab.find_by(version: incoming_version, size: incoming_size, moab_storage_root: ms_root)
            expect(new_cm).not_to be_nil
            expect(new_cm.status).to eq 'validity_unknown'
          end

          it_behaves_like 'calls AuditResults.report_results', :check_existence

          context 'returns' do
            let(:results) { complete_moab_handler.check_existence }

            it 'returns 2 results including expected messages' do
              expect(results).to be_an_instance_of Array
              expect(results.size).to eq 2
              expect(results).to include(a_hash_including(AuditResults::DB_OBJ_DOES_NOT_EXIST => exp_cm_not_exist_msg))
              expect(results).to include(a_hash_including(AuditResults::CREATED_NEW_OBJECT => exp_obj_created_msg))
            end
          end

          context 'db update error (ActiveRecordError)' do
            let(:results) do
              allow(Rails.logger).to receive(:log)
              po = instance_double(PreservedObject, complete_moabs: instance_double(ActiveRecord::Relation))
              allow(po.complete_moabs).to receive(:create!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
              allow(PreservedObject).to receive(:create!).with(hash_including(druid: valid_druid)).and_return(po)
              complete_moab_handler.check_existence
            end

            it 'transaction is rolled back' do
              expect(CompleteMoab.find_by(moab_storage_root: ms_root)).to be_nil
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
          let(:ms_root) { MoabStorageRoot.find_by(storage_location: storage_dir) }
          let(:invalid_druid) { 'xx000xx0000' }
          let(:complete_moab_handler) { described_class.new(invalid_druid, incoming_version, incoming_size, ms_root) }

          before do
            # add storage root with the invalid moab to the MoabStorageRoots table
            MoabStorageRoot.find_or_create_by!(name: 'bad_fixture_dir') do |msr|
              msr.storage_location = storage_dir
            end
          end

          it 'creates PreservedObject; CompleteMoab with "invalid_moab" status' do
            complete_moab_handler.check_existence
            new_cm = CompleteMoab.find_by(size: incoming_size, moab_storage_root: ms_root, version: incoming_version)
            expect(new_cm).to be_a(CompleteMoab)
            expect(new_cm.status).to eq('invalid_moab')
            expect(new_cm.preserved_object.druid).to eq(invalid_druid)
          end

          it_behaves_like 'calls AuditResults.report_results', :check_existence

          context 'returns' do
            let(:results) { complete_moab_handler.check_existence }

            it '3 results with expected messages' do
              exp_moab_errs_msg = 'Invalid Moab, validation errors: ["Missing directory: [\\"data\\", \\"manifests\\"] Version: v0001"]'
              expect(results).to be_an_instance_of Array
              expect(results.size).to eq 3
              expect(results).to include(a_hash_including(AuditResults::INVALID_MOAB => exp_moab_errs_msg))
              expect(results).to include(a_hash_including(AuditResults::DB_OBJ_DOES_NOT_EXIST => exp_cm_not_exist_msg))
              expect(results).to include(a_hash_including(AuditResults::CREATED_NEW_OBJECT => exp_obj_created_msg))
            end
          end

          context 'db update error (ActiveRecordError)' do
            let(:result_code) { AuditResults::DB_UPDATE_FAILED }
            let(:results) do
              po = instance_double(PreservedObject, complete_moabs: instance_double(ActiveRecord::Relation))
              allow(po.complete_moabs).to receive(:create!).and_raise(ActiveRecord::ActiveRecordError, 'foo')
              allow(PreservedObject).to receive(:create!).with(hash_including(druid: invalid_druid)).and_return(po)
              complete_moab_handler.check_existence
            end

            before { allow(Rails.logger).to receive(:log) }

            it 'transaction is rolled back' do
              expect(CompleteMoab.find_by(moab_storage_root: ms_root)).to be_nil
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
