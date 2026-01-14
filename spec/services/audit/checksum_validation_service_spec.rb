# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Audit::ChecksumValidationService do
  let(:druid) { 'zz102hs9687' }
  let(:root_name) { 'fixture_sr3' }
  let(:moab_store_root) { MoabStorageRoot.find_by!(name: root_name) }
  let(:object_dir) { "#{moab_store_root.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}" }
  let(:moab_record) { create(:preserved_object_fixture, druid: druid).moab_record }
  let(:checksum_validation_service) { described_class.new(moab_record, logger: logger_double) }
  let(:moab_on_storage_validator) { checksum_validation_service.send(:moab_on_storage_validator) }
  let(:results) { instance_double(Audit::Results) }
  let(:logger_double) { instance_double(ActiveSupport::Logger, info: nil, error: nil, add: nil) }
  let(:audit_workflow_reporter) { instance_double(ResultsReporters::AuditWorkflowReporter, report_errors: nil, report_completed: nil) }
  let(:honeybadger_reporter) { instance_double(ResultsReporters::HoneybadgerReporter, report_errors: nil, report_completed: nil) }
  let(:event_service_reporter) { instance_double(ResultsReporters::EventServiceReporter, report_errors: nil, report_completed: nil) }
  let(:logger_reporter) { instance_double(ResultsReporters::LoggerReporter, report_errors: nil, report_completed: nil) }

  before do
    allow(ResultsReporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
    allow(ResultsReporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
    allow(ResultsReporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(ResultsReporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
  end

  describe '#validate_checksums' do
    context 'moab is missing from storage' do
      before do
        # fake a moab gone missing by updating the preserved object to use a non-existent druid
        moab_record.preserved_object.update(druid: 'tr808sp1200')
        allow(Dor::Event::Client).to receive(:create).with(druid: 'druid:tr808sp1200', type: 'preservation_audit_failure', data: instance_of(Hash))
      end

      it 'sets status to moab_on_storage_not_found and adds corresponding audit result' do
        expect { checksum_validation_service.validate_checksums }.to change(moab_record, :status).to 'moab_on_storage_not_found'
        expect(moab_record.reload.status).to eq 'moab_on_storage_not_found'
        expect(checksum_validation_service.results.results.first).to have_key(:moab_not_found)
      end

      it 'sends results in HONEYBADGER_REPORT_CODES errors' do
        reason = 'db MoabRecord \\(created .*Z; last updated .*Z\\) exists but Moab not found'
        checksum_validation_service.validate_checksums

        expect(honeybadger_reporter).to have_received(:report_errors)
          .with(druid: 'tr808sp1200',
                version: 0,
                storage_area: moab_store_root,
                check_name: 'validate_checksums',
                results: [{ moab_not_found: match(reason) },
                          { moab_record_status_changed: 'MoabRecord status changed from validity_unknown to moab_on_storage_not_found' }])
        expect(event_service_reporter).to have_received(:report_errors)
          .with(druid: 'tr808sp1200',
                version: 0,
                storage_area: moab_store_root,
                check_name: 'validate_checksums',
                results: [{ moab_not_found: match(reason) },
                          { moab_record_status_changed: 'MoabRecord status changed from validity_unknown to moab_on_storage_not_found' }])
      end

      it 'calls Audit::Results.report_results' do
        expect(AuditResultsReporter).to receive(:report_results).with(audit_results: Audit::Results, logger: logger_double)
        checksum_validation_service.validate_checksums
      end
    end

    context 'moab is empty' do
      before do
        # fake a moab gone missing by updating the preserved object to use a druid with an empty directory
        moab_record.preserved_object.update(druid: 'bh868zf9366')
        allow(Dor::Event::Client).to receive(:create).with(druid: 'druid:bh868zf9366', type: 'preservation_audit_failure', data: instance_of(Hash))
      end

      it 'sets status to moab_on_storage_not_found and adds corresponding audit result' do
        expect(checksum_validation_service.moab_on_storage.object_pathname.exist?).to be true
        expect { checksum_validation_service.validate_checksums }.to change(moab_record, :status).to 'moab_on_storage_not_found'
        expect(moab_record.reload.status).to eq 'moab_on_storage_not_found'
        expect(checksum_validation_service.results.results.first).to have_key(:moab_not_found)
      end

      it 'sends results in HONEYBADGER_REPORT_CODES errors' do
        reason = 'db MoabRecord \\(created .*Z; last updated .*Z\\) exists but Moab not found'
        checksum_validation_service.validate_checksums

        expect(honeybadger_reporter).to have_received(:report_errors)
          .with(druid: 'bh868zf9366',
                version: 0,
                storage_area: moab_store_root,
                check_name: 'validate_checksums',
                results: [{ moab_not_found: match(reason) },
                          { moab_record_status_changed: 'MoabRecord status changed from validity_unknown to moab_on_storage_not_found' }])
        expect(event_service_reporter).to have_received(:report_errors)
          .with(druid: 'bh868zf9366',
                version: 0,
                storage_area: moab_store_root,
                check_name: 'validate_checksums',
                results: [{ moab_not_found: match(reason) },
                          { moab_record_status_changed: 'MoabRecord status changed from validity_unknown to moab_on_storage_not_found' }])
      end

      it 'calls AuditResultReporter.report_results' do
        expect(AuditResultsReporter).to receive(:report_results).with(audit_results: Audit::Results, logger: logger_double)
        checksum_validation_service.validate_checksums
      end
    end

    context 'passes checksum validation' do
      let(:druid) { 'bz514sm9647' }
      let(:root_name) { 'fixture_sr1' }

      it 'returns a positive result for a moab_record' do
        checksum_validation_service.validate_checksums
        expect(checksum_validation_service.results.results.first).to have_key(:moab_checksum_valid)
      end

      [
        'moab_on_storage_not_found',
        'invalid_moab',
        'unexpected_version_on_storage',
        'invalid_checksum',
        'validity_unknown'
      ].each do |initial_status|
        it "sets status to OK_STATUS if it was previously #{initial_status}" do
          moab_record.status = initial_status
          moab_record.save!
          expect { checksum_validation_service.validate_checksums }.to change(moab_record, :status).to 'ok'
          expect(moab_record.reload.status).to eq 'ok'
        end
      end

      it 'leaves status of OK_STATUS as-is' do
        moab_record.ok!
        expect { checksum_validation_service.validate_checksums }.not_to(change(moab_record, :status))
        expect(moab_record.reload.status).to eq 'ok'
      end

      it 'updates audit timestamps' do
        expect(moab_record.last_moab_validation).to be_nil
        expect(moab_record.last_version_audit).to be_nil
        approximate_validation_time = Time.current
        checksum_validation_service.validate_checksums
        expect(moab_record.last_moab_validation).to be > approximate_validation_time
        expect(moab_record.last_version_audit).to be > approximate_validation_time
      end

      context 'fails other moab validation' do
        context 'version on disk does not match expected version from catalog' do
          before do
            moab_record.version = 4 # this is one greater than the version on disk for bz514sm9647
            moab_record.save!
          end

          [
            'ok',
            'moab_on_storage_not_found',
            'invalid_moab',
            'invalid_checksum',
            'validity_unknown'
          ].each do |initial_status|
            it "sets status to UNEXPECTED_VERSION_ON_STORAGE_STATUS if it was previously #{initial_status}" do
              moab_record.status = initial_status
              moab_record.save!
              expect { checksum_validation_service.validate_checksums }.to change(moab_record, :status).to 'unexpected_version_on_storage'
              expect(checksum_validation_service.results.contains_result_code?(Audit::Results::UNEXPECTED_VERSION)).to be true
              expect(moab_record.reload.status).to eq 'unexpected_version_on_storage'
            end
          end

          it 'leaves status as UNEXPECTED_VERSION_ON_STORAGE_STATUS if MoabRecord started in that state' do
            moab_record.unexpected_version_on_storage!
            expect { checksum_validation_service.validate_checksums }.not_to(change(moab_record, :status))
            expect(checksum_validation_service.results.contains_result_code?(Audit::Results::UNEXPECTED_VERSION)).to be true
            expect(moab_record.reload.status).to eq 'unexpected_version_on_storage'
          end
        end

        context 'moab_validation_errors indicates there are structural errors' do
          before do
            allow_any_instance_of(MoabOnStorage::Validator).to receive(:moab_validation_errors) # rubocop:disable RSpec/AnyInstance
              .and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
          end

          [
            'ok',
            'moab_on_storage_not_found',
            'unexpected_version_on_storage',
            'invalid_checksum',
            'validity_unknown'
          ].each do |initial_status|
            it "sets status as INVALID_MOAB_STATUS if it was #{initial_status}" do
              moab_record.status = initial_status
              moab_record.save!
              expect { checksum_validation_service.validate_checksums }.to change(moab_record, :status).to 'invalid_moab'
              expect(moab_record.reload.status).to eq 'invalid_moab'
            end
          end

          it 'leaves status as INVALID_MOAB_STATUS if MoabRecord started in that state' do
            moab_record.invalid_moab!
            expect { checksum_validation_service.validate_checksums }.not_to(change(moab_record, :status))
            expect(moab_record.reload.status).to eq 'invalid_moab'
          end
        end
      end
    end

    context 'fails checksum validation' do
      it 'returns error codes for a moab_record' do
        checksum_validation_service.validate_checksums
        expect(checksum_validation_service.results.results.first).to have_key(:file_not_in_manifest)
      end

      [
        'ok',
        'moab_on_storage_not_found',
        'invalid_moab',
        'unexpected_version_on_storage',
        'validity_unknown'
      ].each do |initial_status|
        it "sets MoabRecord status to INVALID_CHECKSUM_STATUS if it was initially #{initial_status}" do
          moab_record.status = initial_status
          expect { checksum_validation_service.validate_checksums }.to change(moab_record, :status).to 'invalid_checksum'
        end
      end

      it 'leaves MoabRecord status as INVALID_CHECKSUM_STATUS if it already was' do
        moab_record.status = 'invalid_checksum'
        expect { checksum_validation_service.validate_checksums }.not_to(change(moab_record, :status))
      end

      context 'fails other moab validation' do
        context 'version on disk does not match expected version from catalog' do
          before do
            moab_record.version = 4 # this is one greater than the version on disk for bz514sm9647
            moab_record.save!
          end

          [
            'ok',
            'moab_on_storage_not_found',
            'invalid_moab',
            'validity_unknown',
            'unexpected_version_on_storage'
          ].each do |initial_status|
            it "sets status to INVALID_CHECKSUM_STATUS if it was previously #{initial_status}" do
              moab_record.status = initial_status
              moab_record.save!
              expect { checksum_validation_service.validate_checksums }.to change(moab_record, :status).to 'invalid_checksum'
              expect(moab_record.reload.status).to eq 'invalid_checksum'
            end
          end

          it 'leaves status as INVALID_CHECKSUM_STATUS if MoabRecord started in that state' do
            moab_record.invalid_checksum!
            expect { checksum_validation_service.validate_checksums }.not_to(change(moab_record, :status))
            expect(moab_record.reload.status).to eq 'invalid_checksum'
          end
        end

        context 'moab_validation_errors indicates there are structural errors' do
          before do
            allow(moab_on_storage_validator).to receive(:moab_validation_errors)
              .and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
          end

          [
            'ok',
            'moab_on_storage_not_found',
            'unexpected_version_on_storage',
            'validity_unknown',
            'invalid_moab'
          ].each do |initial_status|
            it "sets status as INVALID_CHECKSUM_STATUS if it was #{initial_status}" do
              moab_record.status = initial_status
              moab_record.save!
              expect { checksum_validation_service.validate_checksums }.to change(moab_record, :status).to 'invalid_checksum'
              expect(moab_record.reload.status).to eq 'invalid_checksum'
            end
          end

          it 'leaves status as INVALID_CHECKSUM_STATUS if MoabRecord started in that state' do
            moab_record.invalid_checksum!
            expect { checksum_validation_service.validate_checksums }.not_to(change(moab_record, :status))
            expect(moab_record.reload.status).to eq 'invalid_checksum'
          end
        end
      end
    end

    context 'reports results' do
      it 'calls Audit::Results.report_results' do
        expect(AuditResultsReporter).to receive(:report_results).with(audit_results: Audit::Results, logger: logger_double)
        checksum_validation_service.validate_checksums
      end
    end

    context 'deals with transactions properly' do
      let(:druid) { 'bz514sm9647' } # should pass validation
      let(:root_name) { 'fixture_sr1' }

      before do
        # would result in a status update if the save succeeded
        moab_record.moab_on_storage_not_found!

        # do this second since we save! as part of setup
        allow(moab_record).to receive(:save!).and_raise(ActiveRecord::ConnectionTimeoutError)
      end

      it 'does not re-throw an ActiveRecord error we know how to deal with' do
        expect { checksum_validation_service.validate_checksums }.not_to raise_error
      end

      it 'has a result code indicating the update failed' do
        checksum_validation_service.validate_checksums
        expect(checksum_validation_service.results.contains_result_code?(Audit::Results::DB_UPDATE_FAILED)).to be true
      end

      it 'does not have a result code indicating the update happened' do
        checksum_validation_service.validate_checksums
        expect(checksum_validation_service.results.contains_result_code?(Audit::Results::MOAB_RECORD_STATUS_CHANGED)).to be false
      end
    end
  end

  describe '#validate_manifest_inventories' do
    context 'when happy path' do
      let(:storage_object_version1) { instance_double(Moab::StorageObjectVersion) }
      let(:storage_object_version2) { instance_double(Moab::StorageObjectVersion) }
      let(:storage_object_version3) { instance_double(Moab::StorageObjectVersion) }
      let(:version_list) { [storage_object_version1, storage_object_version2, storage_object_version3] }
      let(:moab_on_storage) do
        instance_double(Moab::StorageObject, version_list: [storage_object_version1, storage_object_version2, storage_object_version3])
      end

      before do
        allow(checksum_validation_service).to receive(:moab_on_storage).and_return(moab_on_storage)
        allow(Audit::ManifestInventoryValidator).to receive(:validate)
        allow(moab_on_storage).to receive(:current_version_id).and_return(1, 2, 3)
      end

      it 'calls validate_manifest_inventory for each moab_version' do
        checksum_validation_service.send(:validate_manifest_inventories)
        version_list.each do |moab_version|
          expect(Audit::ManifestInventoryValidator)
            .to have_received(:validate).with(moab_version:, checksum_validator: checksum_validation_service.checksum_validator)
        end
      end
    end

    context 'file checksums in manifestInventory.xml do not match' do
      let(:druid) { 'zz925bx9565' }

      before { allow(Audit::Results).to receive(:new).and_return(results) }

      it 'adds a MOAB_FILE_CHECKSUM_MISMATCH result' do
        file_path1 = "#{object_dir}/v0001/manifests/versionAdditions.xml"
        file_path2 = "#{object_dir}/v0002/manifests/versionInventory.xml"
        allow(results).to receive(:add_result).with(
          Audit::Results::MOAB_FILE_CHECKSUM_MISMATCH, file_path: a_string_matching(file_path1), version: 'v1'
        )
        allow(results).to receive(:add_result).with(
          Audit::Results::MOAB_FILE_CHECKSUM_MISMATCH, file_path: a_string_matching(file_path2), version: 'v2'
        )
        checksum_validation_service.send(:validate_manifest_inventories)
        expect(results).to have_received(:add_result).with(
          Audit::Results::MOAB_FILE_CHECKSUM_MISMATCH, file_path: a_string_matching(file_path1), version: 'v1'
        )
        expect(results).to have_received(:add_result).with(
          Audit::Results::MOAB_FILE_CHECKSUM_MISMATCH, file_path: a_string_matching(file_path2), version: 'v2'
        )
      end
    end

    context 'file missing from manifestInventory.xml' do
      before { allow(Audit::Results).to receive(:new).and_return(results) }

      it 'adds a FILE_NOT_IN_MANIFEST result' do
        manifest_file_path = "#{object_dir}/v0003/manifests/manifestInventory.xml"
        file_path = "#{object_dir}/v0003/manifests/versionInventory.xml"
        allow(results).to receive(:add_result).with(
          Audit::Results::FILE_NOT_IN_MANIFEST, file_path: a_string_matching(file_path), manifest_file_path: a_string_matching(manifest_file_path)
        )
        checksum_validation_service.send(:validate_manifest_inventories)
        expect(results).to have_received(:add_result).with(
          Audit::Results::FILE_NOT_IN_MANIFEST, file_path: a_string_matching(file_path), manifest_file_path: a_string_matching(manifest_file_path)
        )
      end
    end

    context 'file not on disk, but is described in manifestInventory.xml' do
      let(:druid) { 'zz514sm9647' }

      before { allow(Audit::Results).to receive(:new).and_return(results) }

      it 'adds a FILE_NOT_IN_MOAB result' do
        manifest_file_path = "#{object_dir}/v0003/manifests/manifestInventory.xml"
        file_path = "#{object_dir}/v0003/manifests/versionInventory.xml"
        allow(results).to receive(:add_result).with(
          Audit::Results::FILE_NOT_IN_MOAB, manifest_file_path: a_string_matching(manifest_file_path), file_path: a_string_matching(file_path)
        )
        checksum_validation_service.send(:validate_manifest_inventories)
        expect(results).to have_received(:add_result).with(
          Audit::Results::FILE_NOT_IN_MOAB, manifest_file_path: a_string_matching(manifest_file_path), file_path: a_string_matching(file_path)
        )
      end
    end

    context 'manifestInventory.xml not found in Moab' do
      let(:druid) { 'zz628nk4868' }

      before { allow(Audit::Results).to receive(:new).and_return(results) }

      it 'adds a MANIFEST_NOT_IN_MOAB' do
        manifest_file_path = 'spec/fixtures/checksum_root01/sdr2objects/zz/628/nk/4868/zz628nk4868/v0001/manifests/manifestInventory.xml'
        allow(results).to receive(:add_result).with(
          Audit::Results::MANIFEST_NOT_IN_MOAB, manifest_file_path: manifest_file_path
        )
        checksum_validation_service.send(:validate_manifest_inventories)
        expect(results).to have_received(:add_result).with(
          Audit::Results::MANIFEST_NOT_IN_MOAB, manifest_file_path: manifest_file_path
        )
      end
    end

    context 'cannot parse manifestInventory.xml file' do
      let(:druid) { 'zz048cw1328' }

      before { allow(Audit::Results).to receive(:new).and_return(results) }

      it 'adds an INVALID_MANIFEST' do
        manifest_file_path = 'spec/fixtures/checksum_root01/sdr2objects/zz/048/cw/1328/zz048cw1328/v0002/manifests/manifestInventory.xml'
        allow(results).to receive(:add_result).with(
          Audit::Results::INVALID_MANIFEST, manifest_file_path: manifest_file_path
        )
        checksum_validation_service.send(:validate_manifest_inventories)
        expect(results).to have_received(:add_result).with(
          Audit::Results::INVALID_MANIFEST, manifest_file_path: manifest_file_path
        )
      end
    end
  end

  describe 'SignatureCatalogValidator#validate_signature_catalog_listing' do
    let(:druid) { 'bj102hs9687' }
    let(:root_name) { 'fixture_sr1' }
    let(:signature_catalog_validator) do
      Audit::SignatureCatalogValidator.new(checksum_validator: checksum_validation_service.checksum_validator)
    end

    it 'calls validate_signature_catalog_entry for each signatureCatalog entry' do
      sce01 = instance_double(Moab::SignatureCatalogEntry)
      entry_list = [sce01] + Array.new(10, sce01.dup)
      allow(checksum_validation_service.checksum_validator).to receive(:moab_storage_object).and_return(instance_double(Moab::StorageObject))
      allow(signature_catalog_validator).to receive(:latest_signature_catalog_entries).and_return(entry_list)
      entry_list.each do |entry|
        expect(signature_catalog_validator).to receive(:validate_signature_catalog_entry).with(entry)
      end
      signature_catalog_validator.send(:validate_signature_catalog_listing)
    end

    context 'file checksums in signatureCatalog.xml do not match' do
      let(:druid) { 'zz111rr1111' }
      let(:root_name) { 'fixture_sr3' }

      before { allow(Audit::Results).to receive(:new).and_return(results) }

      it 'adds a MOAB_FILE_CHECKSUM_MISMATCH result' do
        file_path = "#{object_dir}/v0001/data/content/eric-smith-dissertation-augmented.pdf"
        expect(results).to receive(:add_result).with(
          Audit::Results::MOAB_FILE_CHECKSUM_MISMATCH, { file_path: file_path, version: 1 }
        )
        signature_catalog_validator.send(:validate_signature_catalog_listing)
      end
    end

    context 'SC1258_FUR_032a.jpg not on disk, but its entry element exists in signatureCatalog.xml' do
      let(:druid) { 'tt222tt2222' }
      let(:root_name) { 'fixture_sr3' }

      before { allow(Audit::Results).to receive(:new).and_return(results) }

      it 'adds a FILE_NOT_IN_MOAB error' do
        manifest_file_path = "#{object_dir}/v0003/manifests/signatureCatalog.xml"
        file_path = "#{object_dir}/v0001/data/content/SC1258_FUR_032a.jpg"
        expect(results).to receive(:add_result).with(
          Audit::Results::FILE_NOT_IN_MOAB, { manifest_file_path: manifest_file_path, file_path: file_path }
        )
        signature_catalog_validator.send(:validate_signature_catalog_listing)
      end
    end

    context 'signatureCatalog.xml not found in moab' do
      let(:druid) { 'zz333vv3333' }
      let(:root_name) { 'fixture_sr3' }

      before { allow(Audit::Results).to receive(:new).and_return(results) }

      it 'adds a SIGNATURE_CATALOG_NOT_IN_MOAB error' do
        expect(results).to receive(:add_result).with(
          Audit::Results::SIGNATURE_CATALOG_NOT_IN_MOAB, signature_catalog_path: "#{object_dir}/v0002/manifests/signatureCatalog.xml"
        )
        signature_catalog_validator.send(:validate_signature_catalog_listing)
      end
    end

    context 'cannot parse signatureCatalog.xml' do
      let(:druid) { 'xx444xx4444' }
      let(:root_name) { 'fixture_sr3' }

      before { allow(Audit::Results).to receive(:new).and_return(results) }

      it 'adds an INVALID_MANIFEST error' do
        exp_msg_start = '#<Nokogiri::XML::SyntaxError: 6:28: FATAL: Opening and ending tag mismatch: signatureCatalog'
        expect(results).to receive(:add_result).with(
          Audit::Results::INVALID_MANIFEST, hash_including(manifest_file_path: "#{object_dir}/v0001/manifests/signatureCatalog.xml",
                                                           addl: a_string_starting_with(exp_msg_start))
        )
        signature_catalog_validator.send(:validate_signature_catalog_listing)
      end
    end
  end

  describe 'SignatureCatalogValidator#flag_unexpected_data_files' do
    let(:druid) { 'bj102hs9687' }
    let(:root_name) { 'fixture_sr1' }
    let(:signature_catalog_validator) do
      Audit::SignatureCatalogValidator.new(checksum_validator: checksum_validation_service.checksum_validator)
    end

    it 'calls validate_against_signature_catalog on each of the data_files' do
      # for easier reading, we assume data_files has a smaller return value
      files = ["#{object_dir}/v0001/data/metadata/contentMetadata.xml"]
      expect(signature_catalog_validator).to receive(:data_files).and_return(files)
      allow(signature_catalog_validator).to receive(:validate_against_signature_catalog)
      signature_catalog_validator.send(:flag_unexpected_data_files)
      files.each do |file|
        expect(signature_catalog_validator).to have_received(:validate_against_signature_catalog).with(file)
      end
      expect(signature_catalog_validator).to have_received(:validate_against_signature_catalog).exactly(files.size).times
    end

    context 'files are on disk but not present in signatureCatalog.xml' do
      let(:druid) { 'zz555zz5555' }
      let(:root_name) { 'fixture_sr3' }

      before { allow(Audit::Results).to receive(:new).and_return(results) }

      it 'adds a FILE_NOT_IN_SIGNATURE_CATALOG error' do
        content_file_path = "#{object_dir}/v0001/data/content/not_in_sigcat.txt"
        metadata_file_path = "#{object_dir}/v0001/data/metadata/also_not_in_sigcat.txt"
        nested_file_path = "#{object_dir}/v0001/data/content/unexpected/another_not_in_sigcat.txt"
        signature_catalog_path = "#{object_dir}/v0002/manifests/signatureCatalog.xml"
        expect(results).to receive(:add_result).with(
          Audit::Results::FILE_NOT_IN_SIGNATURE_CATALOG, { file_path: content_file_path, signature_catalog_path: signature_catalog_path }
        )
        expect(results).to receive(:add_result).with(
          Audit::Results::FILE_NOT_IN_SIGNATURE_CATALOG, { file_path: metadata_file_path, signature_catalog_path: signature_catalog_path }
        )
        expect(results).to receive(:add_result).with(
          Audit::Results::FILE_NOT_IN_SIGNATURE_CATALOG, { file_path: nested_file_path, signature_catalog_path: signature_catalog_path }
        )
        signature_catalog_validator.send(:flag_unexpected_data_files)
      end
    end
  end

  describe 'SignatureCatalogValidator#validate' do
    let(:druid) { 'bj102hs9687' }
    let(:root_name) { 'fixture_sr1' }
    let(:signature_catalog_validator) do
      Audit::SignatureCatalogValidator.new(checksum_validator: checksum_validation_service.checksum_validator)
    end

    it 'calls validate_signature_catalog_listing' do
      allow(signature_catalog_validator).to receive(:validate_signature_catalog_listing)
      signature_catalog_validator.send(:validate)
      expect(signature_catalog_validator).to have_received(:validate_signature_catalog_listing)
    end

    it 'calls flag_unexpected_data_content_files' do
      allow(signature_catalog_validator).to receive(:flag_unexpected_data_files)
      signature_catalog_validator.send(:validate)
      expect(signature_catalog_validator).to have_received(:flag_unexpected_data_files)
    end

    context 'file or directory does not exist' do
      let(:druid) { 'yy000yy0000' }
      let(:root_name) { 'fixture_sr2' }

      it 'adds error code and continues executing' do
        allow(results).to receive(:add_result)
        allow(checksum_validation_service).to receive(:results).and_return(results)
        checksum_validation_service.send(:validate_signature_catalog)
        expect(results).to have_received(:add_result).with(
          Audit::Results::SIGNATURE_CATALOG_NOT_IN_MOAB, anything
        ).at_least(:once)
      end
    end

    context 'with unparseable signatureCatalog.xml' do
      let(:druid) { 'xx444xx4444' }
      let(:root_name) { 'fixture_sr3' }

      it 'adds an INVALID_MANIFEST error' do
        allow(results).to receive(:add_result)
        allow(checksum_validation_service).to receive(:results).and_return(results)
        exp_msg_start = '#<Nokogiri::XML::SyntaxError: 6:28: FATAL: Opening and ending tag mismatch: signatureCatalog'
        checksum_validation_service.send(:validate_signature_catalog)
        expect(results).to have_received(:add_result).with(
          Audit::Results::INVALID_MANIFEST, hash_including(manifest_file_path: "#{object_dir}/v0001/manifests/signatureCatalog.xml",
                                                           addl: a_string_starting_with(exp_msg_start))
        )
      end
    end

    context 'with empty signatureCatalog.xml' do
      let(:druid) { 'yg880zm4762' }
      let(:root_name) { 'fixture_sr3' }

      it 'adds error code and continues executing' do
        allow(results).to receive(:add_result)
        allow(checksum_validation_service).to receive(:results).and_return(results)
        exp_msg_start = '#<Nokogiri::XML::SyntaxError: 1:1: FATAL: Document is empty'
        checksum_validation_service.send(:validate_signature_catalog)
        expect(results).to have_received(:add_result).with(
          Audit::Results::INVALID_MANIFEST, hash_including(manifest_file_path: "#{object_dir}/v0001/manifests/signatureCatalog.xml",
                                                           addl: a_string_starting_with(exp_msg_start))
        ).at_least(:once)
      end
    end
  end

  context 'checksums are configurable' do
    it 'all three checksums at once' do
      allow(Moab::Config).to receive(:checksum_algos).and_return(%i[md5 sha1 sha256])
      expect(Digest::MD5).to receive(:new).and_call_original.at_least(:once)
      expect(Digest::SHA1).to receive(:new).and_call_original.at_least(:once)
      expect(Digest::SHA2).to receive(:new).and_call_original.at_least(:once)
      checksum_validation_service.validate_checksums
    end

    it 'defaults to md5 only' do
      expect(Digest::MD5).to receive(:new).and_call_original.at_least(:once)
      expect(Digest::SHA1).not_to receive(:new).and_call_original
      expect(Digest::SHA2).not_to receive(:new).and_call_original
      checksum_validation_service.validate_checksums
    end

    it 'sha256 only' do
      allow(Moab::Config).to receive(:checksum_algos).and_return([:sha256])
      expect(Digest::MD5).not_to receive(:new).and_call_original
      expect(Digest::SHA1).not_to receive(:new).and_call_original
      expect(Digest::SHA2).to receive(:new).and_call_original.at_least(:once)
      checksum_validation_service.validate_checksums
    end
  end

  context 'preservationAuditWF reporting' do
    let(:druid) { 'bz514sm9647' }
    let(:root_name) { 'fixture_sr1' }

    it 'has status changed to OK_STATUS and completes workflow' do
      moab_record.invalid_moab!
      expect(audit_workflow_reporter).to receive(:report_completed)
        .with(druid: druid,
              version: 3,
              check_name: 'validate_checksums',
              storage_area: moab_store_root,
              result: { moab_record_status_changed: 'MoabRecord status changed from invalid_moab to ok' })
      checksum_validation_service.validate_checksums
    end

    it 'has status that does not change and does not complete workflow' do
      moab_record.ok!
      expect(audit_workflow_reporter).not_to receive(:report_completed)
      checksum_validation_service.validate_checksums
    end

    context 'has status changed to status other than OK_STATUS' do
      before do
        moab_record.version = 4 # this is one greater than the version on disk for bz514sm9647
        moab_record.save!
      end

      it 'does not complete workflow' do
        moab_record.ok!
        expect(audit_workflow_reporter).not_to receive(:report_completed)
        checksum_validation_service.validate_checksums
      end
    end

    context 'transaction is rolled back' do
      before do
        # would result in a status update if the save succeeded
        moab_record.moab_on_storage_not_found!

        # do this second since we save! as part of setup
        allow(moab_record).to receive(:save!).and_raise(ActiveRecord::ConnectionTimeoutError)
      end

      it 'does not complete workflow' do
        expect(audit_workflow_reporter).not_to receive(:report_completed)
        checksum_validation_service.validate_checksums
      end
    end
  end
end
