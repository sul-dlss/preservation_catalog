# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Audit::CatalogToMoab do
  let(:last_checked_version_b4_date) { (Time.now.utc - 1.day).iso8601 }
  let(:storage_location) { 'spec/fixtures/storage_root01/sdr2objects' }
  let(:druid) { 'bj102hs9687' }
  let(:c2m) { described_class.new(comp_moab) }
  let(:moab_on_storage_validator) { c2m.send(:moab_on_storage_validator) }
  let(:mock_sov) { instance_double(Stanford::StorageObjectValidator) }
  let(:po) { create(:preserved_object_fixture, druid: druid) }
  let(:comp_moab) do
    MoabStorageRoot.find_by!(storage_location: storage_location).complete_moabs.find_by!(preserved_object: po)
  end
  let(:logger_double) { instance_double(Logger, info: nil, error: nil, add: nil) }
  let(:results_double) do
    instance_double(AuditResults,
                    add_result: nil,
                    results: [],
                    results_as_string: nil)
  end
  let(:exp_details_prefix) { 'check_catalog_version (actual location: fixture_sr1; ' }
  let(:hb_exp_msg) do
    'check_catalog_version\\(bj102hs9687, fixture_sr1\\)' \
      'db CompleteMoab \\(created .*Z; last updated .*Z\\) exists but Moab not found'
  end
  let(:audit_workflow_reporter) { instance_double(Reporters::AuditWorkflowReporter, report_errors: nil) }
  let(:event_service_reporter) { instance_double(Reporters::EventServiceReporter, report_errors: nil) }
  let(:honeybadger_reporter) { instance_double(Reporters::HoneybadgerReporter, report_errors: nil) }
  let(:logger_reporter) { instance_double(Reporters::LoggerReporter, report_errors: nil) }

  before do
    allow(Reporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
    allow(Reporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
    allow(Reporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(Reporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
    allow(c2m).to receive(:logger).and_return(logger_double) # silence log output
    allow(AuditResultsReporter).to receive(:report_results).and_return([])
  end

  describe '#check_catalog_version' do
    let(:object_dir) { "#{storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}" }
    let(:b4_details) { 'before details' }

    before { comp_moab.ok! }

    it 'instantiates Moab::StorageObject from druid and storage_location' do
      expect(Moab::StorageObject).to receive(:new).with(druid, a_string_matching(object_dir)).and_call_original
      c2m.check_catalog_version
    end

    it 'gets the current version on disk from the Moab::StorageObject' do
      moab = instance_double(Moab::StorageObject, object_pathname: object_dir)
      allow(Moab::StorageObject).to receive(:new).with(druid, String).and_return(moab)
      expect(moab).to receive(:current_version_id).twice.and_return(3)
      c2m.check_catalog_version
    end

    it 'calls CompleteMoab.update_audit_timestamps' do
      expect(comp_moab).to receive(:update_audit_timestamps).with(anything, true)
      c2m.check_catalog_version
    end

    it 'calls CompleteMoab.save!' do
      expect(comp_moab).to receive(:save!)
      c2m.check_catalog_version
    end

    it 'calls AuditResultsReporter.report_results' do
      c2m.instance_variable_set(:@results, results_double)
      expect(AuditResultsReporter).to receive(:report_results).with(audit_results: c2m.results, logger: Logger)
      c2m.check_catalog_version
    end

    context 'moab is nil (exists in catalog but not online)' do
      before do
        allow(Moab::StorageObject).to receive(:new).with(druid, String).and_return(nil)
        allow(Honeybadger).to receive(:notify).with(Regexp.new(hb_exp_msg))
      end

      it 'adds a MOAB_NOT_FOUND result' do
        c2m.instance_variable_set(:@results, results_double)
        expect(c2m.results).to receive(:add_result).with(
          AuditResults::MOAB_NOT_FOUND, db_created_at: anything, db_updated_at: anything
        )
        expect(c2m.results).to receive(:add_result).with(
          AuditResults::CM_STATUS_CHANGED, old_status: 'ok', new_status: 'online_moab_not_found'
        )
        c2m.check_catalog_version
      end

      context 'updates status and status_details correctly' do
        [
          'validity_unknown',
          'ok',
          'online_moab_not_found',
          'invalid_moab',
          'unexpected_version_on_storage',
          'invalid_checksum'
        ].each do |orig_status|
          context "had #{orig_status};" do
            before do
              comp_moab.status = orig_status
              comp_moab.status_details = b4_details
              comp_moab.save!
              c2m.check_catalog_version
            end

            it "status becomes 'online_moab_not_found'" do
              expect(comp_moab.reload.status).to eq 'online_moab_not_found'
            end

            it 'status_details updated' do
              exp = "#{exp_details_prefix}) "
              exp += "CompleteMoab status changed from #{orig_status} to online_moab_not_found" unless orig_status == 'online_moab_not_found'
              expect(comp_moab.reload.status_details).to eq exp
            end
          end
        end
      end

      context 'DB transaction handling' do
        it 'on transaction failure, completes without raising error, removes CM_STATUS_CHANGED result code' do
          allow(comp_moab).to receive(:save!).and_raise(ActiveRecord::ConnectionTimeoutError)
          c2m.check_catalog_version
          expect(c2m.results.results).to include(a_hash_including(AuditResults::MOAB_NOT_FOUND))
          expect(c2m.results.results).not_to include(a_hash_including(AuditResults::CM_STATUS_CHANGED))
          expect(comp_moab.reload.status).not_to eq 'online_moab_not_found'
        end
      end
    end

    context 'complete_moab version != current_version of preserved_object' do
      # database is inconsistent with itself!
      before do
        comp_moab.version = 666
        comp_moab.status_details = b4_details
        comp_moab.ok!
        allow(Moab::StorageObject).to receive(:new).with(druid, a_string_matching(object_dir))
        c2m.instance_variable_set(:@results, results_double)
        allow(c2m.results).to receive(:add_result).with(
          AuditResults::CM_PO_VERSION_MISMATCH,
          cm_version: comp_moab.version,
          po_version: comp_moab.preserved_object.current_version
        )
        allow(AuditResultsReporter).to receive(:report_results).with(audit_results: c2m.results)
        c2m.check_catalog_version
      end

      it 'adds a CM_PO_VERSION_MISMATCH result and finishes processing' do
        expect(Moab::StorageObject).not_to have_received(:new).with(druid, a_string_matching(object_dir))
        expect(c2m.results).to have_received(:add_result).with(
          AuditResults::CM_PO_VERSION_MISMATCH,
          cm_version: comp_moab.version,
          po_version: comp_moab.preserved_object.current_version
        )
      end

      it 'calls AuditResultsReporter.report_results' do
        expect(AuditResultsReporter).to have_received(:report_results).with(audit_results: c2m.results, logger: Logger)
      end

      it 'does NOT update status' do
        expect(comp_moab.reload.status).to eq 'ok'
      end

      it 'does NOT update status_details' do
        expect(comp_moab.reload.status_details).to eq b4_details
      end
    end

    context 'catalog version == moab version (happy path)' do
      it 'adds a VERSION_MATCHES result' do
        c2m.instance_variable_set(:@results, results_double)
        expect(c2m.results).to receive(:add_result).with(AuditResults::VERSION_MATCHES, 'CompleteMoab')
        c2m.check_catalog_version
      end

      context "starts with status 'ok'" do
        before do
          c2m.instance_variable_set(:@results, results_double)
          allow(c2m.results).to receive(:add_result).with(AuditResults::VERSION_MATCHES, 'CompleteMoab')
          comp_moab.status_details = b4_details
          comp_moab.ok!
          c2m.check_catalog_version
        end

        it 'does NOT update status' do
          expect(comp_moab.reload).to be_ok
        end

        it 'does NOT update status_details' do
          expect(comp_moab.reload.status_details).to eq b4_details
        end
      end

      context "re-check when CompleteMoab does not start with status 'ok'" do
        [
          'validity_unknown',
          'online_moab_not_found',
          'invalid_moab',
          'unexpected_version_on_storage'
        ].each do |orig_status|
          context "had #{orig_status} and found no moab validation errors;" do
            before do
              comp_moab.status = orig_status
              comp_moab.status_details = b4_details
              comp_moab.save!
              allow(moab_on_storage_validator).to receive(:moab_validation_errors).and_return([])
              c2m.check_catalog_version
            end

            it 'status becomes validity_unknown' do
              expect(comp_moab.reload.status).to eq 'validity_unknown'
            end

            it 'updates status_details' do
              exp = "#{exp_details_prefix}actual version: 3) "
              exp += "CompleteMoab status changed from #{orig_status} to validity_unknown" unless orig_status == 'validity_unknown'
              expect(comp_moab.reload.status_details).to eq exp
            end
          end
        end

        # 'ok' intentionally omitted, since we don't check status on disk if versions match
        [
          'validity_unknown',
          'online_moab_not_found',
          'invalid_moab',
          'unexpected_version_on_storage'
        ].each do |orig_status|
          context "had #{orig_status} and found moab validation errors;" do
            before do
              comp_moab.status = orig_status
              comp_moab.status_details = b4_details
              comp_moab.save!
              allow(moab_on_storage_validator).to receive(:moab_validation_errors).and_return(
                [{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }]
              )
              c2m.check_catalog_version
            end

            it 'status becomes INVALID_MOAB_STATUS' do
              expect(comp_moab.reload.status).to eq 'invalid_moab'
            end

            it 'updates status_details' do
              exp = "#{exp_details_prefix}actual version: 3) "
              exp += "CompleteMoab status changed from #{orig_status} to invalid_moab" unless orig_status == 'invalid_moab'
              expect(comp_moab.reload.status_details).to eq exp
            end
          end
        end

        context 'started with INVALID_CHECKSUM_STATUS' do
          before do
            comp_moab.status_details = b4_details
            comp_moab.invalid_checksum!
            comp_moab.save!
            allow(moab_on_storage_validator).to receive(:moab_validation_errors).and_return(
              [{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }]
            )
            c2m.check_catalog_version
          end

          it 'status remains invalid_checksum' do
            expect(comp_moab.reload.status).to eq 'invalid_checksum'
          end

          it 'does NOT update status_details' do
            expect(comp_moab.reload.status_details).to eq b4_details
          end

          it 'has an AuditResults entry indicating inability to check the given status' do
            expect(c2m.results.contains_result_code?(AuditResults::UNABLE_TO_CHECK_STATUS)).to be true
          end
        end
      end
    end

    context 'catalog version < moab version' do
      before do
        moab = instance_double(Moab::StorageObject, size: 666, object_pathname: object_dir)
        allow(Moab::StorageObject).to receive(:new).with(druid, instance_of(String)).and_return(moab)
        allow(moab).to receive(:current_version_id).and_return(4)
      end

      it 'calls update_version_after_validation' do
        expect(CompleteMoabService::UpdateVersionAfterValidation).to receive(:execute)
        c2m.check_catalog_version
      end

      context 'runs validations other than checksum' do
        context 'no validation errors' do
          [
            'validity_unknown',
            'ok',
            'online_moab_not_found',
            'invalid_moab',
            'unexpected_version_on_storage'
          ].each do |orig_status|
            context "had #{orig_status};" do
              before do
                comp_moab.status = orig_status
                comp_moab.status_details = b4_details
                comp_moab.save!
                allow(mock_sov).to receive(:validation_errors).and_return([])
                allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
                c2m.check_catalog_version
              end

              it "status becomes 'validity_unknown'" do
                expect(comp_moab.reload).to be_validity_unknown
              end

              it 'status_details updated' do
                exp = "#{exp_details_prefix}actual version: 4) "
                exp += "CompleteMoab status changed from #{orig_status} to validity_unknown" unless orig_status == 'validity_unknown'
                expect(comp_moab.reload.status_details).to eq exp
              end
            end
          end
        end

        context 'finds validation errors' do
          [
            'validity_unknown',
            'ok',
            'online_moab_not_found',
            'unexpected_version_on_storage'
          ].each do |orig_status|
            context "had #{orig_status}" do
              before do
                comp_moab.status = orig_status
                comp_moab.status_details = b4_details
                comp_moab.save!
                allow(mock_sov).to receive(:validation_errors).and_return(
                  [{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }]
                )
                allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
                c2m.check_catalog_version
              end

              it "status becomes 'invalid_moab'" do
                expect(comp_moab.reload.status).to eq 'invalid_moab'
              end

              it 'status_details updated' do
                exp = exp_details_prefix + 'actual version: 4) Invalid Moab, validation errors: ["err msg"] && ' \
                                           "CompleteMoab status changed from #{orig_status} to invalid_moab"
                expect(comp_moab.reload.status_details).to eq exp
              end
            end
          end

          it 'invalid_moab changes to validity_unknown (due to newer version not checksum validated)' do
            comp_moab.invalid_moab!
            allow(mock_sov).to receive(:validation_errors).and_return(
              [{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }]
            )
            allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
            c2m.check_catalog_version
            expect(comp_moab.reload.status).to eq 'validity_unknown'
            exp_details_postfix = 'actual version: 4) Invalid Moab, validation errors: ["err msg"]'
            expect(comp_moab.status_details).to eq "#{exp_details_prefix}#{exp_details_postfix}"
          end
        end

        context 'starts with INVALID_CHECKSUM_STATUS (which C2M cannot validate)' do
          before do
            allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
            comp_moab.invalid_checksum!
          end

          it 'may have moab validation errors but does not update status or status_details' do
            orig_details = comp_moab.status_details
            allow(mock_sov).to receive(:validation_errors).and_return(
              [{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }]
            )
            c2m.check_catalog_version
            expect(comp_moab.reload.status).to eq 'invalid_checksum'
            expect(comp_moab.status_details).to eq orig_details
          end

          it 'without moab validation errors does not update status or status_details' do
            orig_details = comp_moab.status_details
            allow(mock_sov).to receive(:validation_errors).and_return([])
            c2m.check_catalog_version
            expect(comp_moab.reload.status).to eq 'invalid_checksum'
            expect(comp_moab.status_details).to eq orig_details
          end

          it 'has an AuditResults entry indicating inability to check the given status' do
            c2m.check_catalog_version
            expect(c2m.results.contains_result_code?(AuditResults::UNABLE_TO_CHECK_STATUS)).to be true
          end
        end
      end
    end

    context 'catalog version > moab version' do
      before do
        moab = instance_double(Moab::StorageObject, size: 666, object_pathname: object_dir, current_version_id: 2)
        allow(Moab::StorageObject).to receive(:new).with(druid, instance_of(String)).and_return(moab)
      end

      it 'adds an UNEXPECTED_VERSION result' do
        c2m.instance_variable_set(:@results, results_double)
        expect(c2m.results).to receive(:add_result).with(
          AuditResults::UNEXPECTED_VERSION, db_obj_name: 'CompleteMoab', db_obj_version: comp_moab.version
        )
        c2m.check_catalog_version
      end

      it 'calls Stanford::StorageObjectValidator.validation_errors for moab' do
        expect(mock_sov).to receive(:validation_errors).and_return([])
        allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
        c2m.check_catalog_version
      end

      it 'valid moab sets status to "unexpected_version_on_storage"' do
        orig = comp_moab.status
        expect(orig).to eq 'ok'
        c2m.check_catalog_version
        new_status = comp_moab.reload.status
        expect(new_status).not_to eq orig
        expect(new_status).to eq 'unexpected_version_on_storage'
      end

      it 'valid moab updates status_details' do
        c2m.check_catalog_version
        exp = "#{exp_details_prefix}actual version: 2) CompleteMoab status changed from ok to unexpected_version_on_storage"
        expect(comp_moab.reload.status_details).to eq exp
      end

      context 'moab not found' do
        before do
          allow(mock_sov).to receive(:validation_errors).and_raise(Errno::ENOENT)
          allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
          my_results_double = instance_double(AuditResults,
                                              add_result: nil,
                                              results: [],
                                              results_as_string: 'mock results as string')
          c2m.instance_variable_set(:@results, my_results_double)
          allow(c2m.results).to receive(:add_result).with(AuditResults::MOAB_NOT_FOUND, anything)
          c2m.check_catalog_version
        end

        it 'sets status to online_moab_not_found' do
          expect(comp_moab.reload.status).to eq 'online_moab_not_found'
        end

        it 'updates status_details' do
          expect(comp_moab.reload.status_details).to eq 'mock results as string'
        end

        it 'adds a MOAB_NOT_FOUND result' do
          expect(c2m.results).to have_received(:add_result).with(AuditResults::MOAB_NOT_FOUND, anything)
        end
      end

      context 'invalid moab' do
        before do
          allow(mock_sov).to receive(:validation_errors).and_return([foo: 'error message'])
          allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
          my_results_double = instance_double(AuditResults,
                                              add_result: nil,
                                              results: [],
                                              results_as_string: 'mock results as string')
          c2m.instance_variable_set(:@results, my_results_double)
          allow(c2m.results).to receive(:add_result).with(AuditResults::INVALID_MOAB, anything)
          c2m.check_catalog_version
        end

        it 'sets status to INVALID_MOAB_STATUS' do
          expect(comp_moab.reload.status).to eq 'invalid_moab'
        end

        it 'updates status_details' do
          expect(comp_moab.reload.status_details).to eq 'mock results as string'
        end

        it 'adds an INVALID_MOAB result' do
          expect(c2m.results).to have_received(:add_result).with(AuditResults::INVALID_MOAB, anything)
        end
      end

      it 'adds a CM_STATUS_CHANGED result' do
        c2m.instance_variable_set(:@results, results_double)
        expect(c2m.results).to receive(:add_result).with(
          AuditResults::CM_STATUS_CHANGED, a_hash_including(:old_status, :new_status)
        )
        c2m.check_catalog_version
      end

      context 'check whether CompleteMoab already has a status other than OK_STATUS, re-check status if possible' do
        [
          'validity_unknown',
          'ok',
          'online_moab_not_found',
          'invalid_moab',
          'unexpected_version_on_storage'
        ].each do |orig_status|
          context "had #{orig_status};" do
            before do
              comp_moab.status = orig_status
              comp_moab.status_details = b4_details
              comp_moab.save!
              allow(moab_on_storage_validator).to receive(:moab_validation_errors).and_return([])
              c2m.check_catalog_version
            end

            it 'status becomes unexpected_version_on_storage' do
              expect(comp_moab.reload.status).to eq 'unexpected_version_on_storage'
            end

            it 'status_details updated' do
              exp = "#{exp_details_prefix}actual version: 2) "
              unless orig_status == 'unexpected_version_on_storage'
                exp += "CompleteMoab status changed from #{orig_status} to unexpected_version_on_storage"
              end
              expect(comp_moab.reload.status_details).to eq exp
            end
          end
        end

        [
          'validity_unknown',
          'ok',
          'online_moab_not_found',
          'invalid_moab',
          'unexpected_version_on_storage'
        ].each do |orig_status|
          context "had #{orig_status};" do
            before do
              comp_moab.status = orig_status
              comp_moab.status_details = b4_details
              comp_moab.save!
              allow(moab_on_storage_validator).to receive(:moab_validation_errors).and_return(
                [{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }]
              )
              c2m.check_catalog_version
            end

            it "status becomes 'invalid_moab'" do
              expect(comp_moab.reload.status).to eq 'invalid_moab'
            end

            it 'status_details updated' do
              exp = "#{exp_details_prefix}actual version: 2) "
              exp += "CompleteMoab status changed from #{orig_status} to invalid_moab" unless orig_status == 'invalid_moab'
              expect(comp_moab.reload.status_details).to eq exp
            end
          end
        end

        context 'had INVALID_CHECKSUM_STATUS, which C2M cannot validate' do
          before do
            allow(Stanford::StorageObjectValidator).to receive(:new).and_return(mock_sov)
            comp_moab.status_details = b4_details
            comp_moab.invalid_checksum!
          end

          it 'may have moab validation errors but does not update status or status_details' do
            allow(mock_sov).to receive(:validation_errors).and_return(
              [{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }]
            )
            c2m.check_catalog_version
            expect(comp_moab.reload.status).to eq 'invalid_checksum'
            expect(comp_moab.reload.status_details).to eq b4_details
          end

          it 'without moab validation errors does not update status or status_details' do
            allow(mock_sov).to receive(:validation_errors).and_return([])
            c2m.check_catalog_version
            expect(comp_moab.reload.status).to eq 'invalid_checksum'
            expect(comp_moab.reload.status_details).to eq b4_details
          end

          it 'has an AuditResults entry indicating inability to check the given status' do
            c2m.check_catalog_version
            expect(c2m.results.contains_result_code?(AuditResults::UNABLE_TO_CHECK_STATUS)).to be true
          end
        end
      end
    end

    context 'moab found on disk' do
      # use the same setup as 'catalog version > moab version', since we know that should
      # lead to an update_complete_moab_status('unexpected_version_on_storage') call
      before do
        moab = instance_double(Moab::StorageObject, size: 666, object_pathname: object_dir)
        allow(Moab::StorageObject).to receive(:new).with(druid, instance_of(String)).and_return(moab)
        allow(moab).to receive(:current_version_id).and_return(2)
      end

      context 'DB transaction handling' do
        it 'on transaction failure, completes without raising error, removes CM_STATUS_CHANGED result code' do
          allow(comp_moab).to receive(:save!).and_raise(ActiveRecord::ConnectionTimeoutError)
          c2m.check_catalog_version
          expect(c2m.results.results).to include(a_hash_including(AuditResults::UNEXPECTED_VERSION))
          expect(c2m.results.results).not_to include(a_hash_including(AuditResults::CM_STATUS_CHANGED))
          expect(comp_moab.reload.status).not_to eq 'unexpected_version_on_storage'
        end
      end
    end
  end
end
