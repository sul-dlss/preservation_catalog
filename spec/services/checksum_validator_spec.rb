require_relative '../../app/services/checksum_validator.rb'
require_relative '../load_fixtures_helper.rb'

RSpec.describe ChecksumValidator do
  include_context 'fixture moabs in db'
  let(:druid) { 'zz102hs9687' }
  let(:endpoint_name) { "fixture_sr3" }
  let(:endpoint) { Endpoint.find_by(endpoint_name: endpoint_name) }
  let(:object_dir) { "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}" }
  let(:pres_copy) do
    po = PreservedObject.find_by(druid: druid)
    PreservedCopy.find_by(preserved_object: po, endpoint: endpoint)
  end
  let(:cv) { described_class.new(pres_copy, endpoint_name) }
  let(:results) { instance_double(AuditResults, report_results: nil, check_name: nil) }

  context '#initialize' do
    it 'sets attributes' do
      expect(cv.preserved_copy).to eq pres_copy
      expect(cv.bare_druid).to eq druid
      expect(cv.endpoint).to eq endpoint
      expect(cv.full_druid).to eq "druid:#{druid}"
      expect(cv.results).to be_an_instance_of AuditResults
    end
  end

  context '#validate_manifest_inventories' do
    it 'instantiates moab_storage_object from druid and druid_path' do
      expect(Moab::StorageObject).to receive(:new).with(cv.full_druid, a_string_matching(object_dir)).and_call_original
      cv.validate_manifest_inventories
    end

    it 'calls validate_manifest_inventory for each moab_version' do
      sov1 = instance_double(Moab::StorageObjectVersion)
      sov2 = instance_double(Moab::StorageObjectVersion)
      sov3 = instance_double(Moab::StorageObjectVersion)
      version_list = [sov1, sov2, sov3]
      moab_storage_object = instance_double(Moab::StorageObject, version_list: [sov1, sov2, sov3])
      allow(cv).to receive(:moab_storage_object).and_return(moab_storage_object)
      version_list.each do |moab_version|
        expect(cv).to receive(:validate_manifest_inventory).with(moab_version)
      end
      cv.validate_manifest_inventories
    end

    context 'file checksums in manifestInventory.xml do not match' do
      let(:druid) { 'zz925bx9565' }
      let(:results) { instance_double(AuditResults, report_results: nil, :check_name= => nil) }

      before { allow(AuditResults).to receive(:new).and_return(results) }

      it 'adds a MOAB_FILE_CHECKSUM_MISMATCH result' do
        object_dir = "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        file_path1 = "#{object_dir}/v0001/manifests/versionAdditions.xml"
        file_path2 = "#{object_dir}/v0002/manifests/versionInventory.xml"
        expect(results).to receive(:add_result).with(
          AuditResults::MOAB_FILE_CHECKSUM_MISMATCH, file_path: a_string_matching(file_path1), version: "v1"
        )
        expect(results).to receive(:add_result).with(
          AuditResults::MOAB_FILE_CHECKSUM_MISMATCH, file_path: a_string_matching(file_path2), version: "v2"
        )
        cv.validate_manifest_inventories
      end
    end

    context 'file missing from manifestInventory.xml' do
      before { allow(AuditResults).to receive(:new).and_return(results) }

      it 'adds a FILE_NOT_IN_MANIFEST result' do
        manifest_file_path = "#{object_dir}/v0003/manifests/manifestInventory.xml"
        file_path = "#{object_dir}/v0003/manifests/versionInventory.xml"
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_MANIFEST, file_path: a_string_matching(file_path), manifest_file_path: a_string_matching(manifest_file_path)
        )
        cv.validate_manifest_inventories
      end
    end

    context 'file not on disk, but is described in manifestInventory.xml' do
      let(:druid) { 'zz514sm9647' }

      before { allow(AuditResults).to receive(:new).and_return(results) }

      it 'adds a FILE_NOT_IN_MOAB result' do
        object_dir = "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        manifest_file_path = "#{object_dir}/v0003/manifests/manifestInventory.xml"
        file_path = "#{object_dir}/v0003/manifests/versionInventory.xml"
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_MOAB, manifest_file_path: a_string_matching(manifest_file_path), file_path: a_string_matching(file_path)
        )
        cv.validate_manifest_inventories
      end
    end

    context 'manifestInventory.xml not found in Moab' do
      let(:druid) { 'zz628nk4868' }

      before { allow(AuditResults).to receive(:new).and_return(results) }

      it 'adds a MANIFEST_NOT_IN_MOAB' do
        manifest_file_path = "spec/fixtures/checksum_root01/moab_storage_trunk/zz/628/nk/4868/zz628nk4868/v0001/manifests/manifestInventory.xml"
        expect(results).to receive(:add_result).with(
          AuditResults::MANIFEST_NOT_IN_MOAB, manifest_file_path: manifest_file_path
        )
        cv.validate_manifest_inventories
      end
    end

    context 'cannot parse xml file' do
      let(:druid) { 'zz048cw1328' }

      before { allow(AuditResults).to receive(:new).and_return(results) }

      it 'adds an INVALID_MANIFEST' do
        manifest_file_path = "spec/fixtures/checksum_root01/moab_storage_trunk/zz/048/cw/1328/zz048cw1328/v0002/manifests/manifestInventory.xml"
        expect(results).to receive(:add_result).with(
          AuditResults::INVALID_MANIFEST, manifest_file_path: manifest_file_path
        )
        cv.validate_manifest_inventories
      end
    end
  end

  context '#validate_signature_catalog_listing' do
    let(:druid) { 'bj102hs9687' }
    let(:endpoint_name) { 'fixture_sr1' }
    let(:results) { instance_double(AuditResults, report_results: nil, :check_name= => nil) }

    it 'instantiates storage_object from druid and druid_path' do
      expect(Moab::StorageObject).to receive(:new).with(cv.full_druid, a_string_matching(object_dir)).and_call_original
      cv.send(:validate_signature_catalog_listing)
    end

    it 'calls validate_signature_catalog_entry for each signatureCatalog entry' do
      sce01 = instance_double(Moab::SignatureCatalogEntry)
      entry_list = [sce01] + Array.new(10, sce01.dup)
      moab_storage_object = instance_double(Moab::StorageObject)
      allow(cv).to receive(:moab_storage_object).and_return(moab_storage_object)
      allow(cv).to receive(:latest_signature_catalog_entries).and_return(entry_list)
      entry_list.each do |entry|
        expect(cv).to receive(:validate_signature_catalog_entry).with(entry)
      end
      cv.send(:validate_signature_catalog_listing)
    end

    context 'file checksums in singatureCatalog.xml do not match' do
      let(:druid) { 'zz111rr1111' }
      let(:endpoint_name) { 'fixture_sr3' }

      before { allow(AuditResults).to receive(:new).and_return(results) }

      it 'adds a MOAB_FILE_CHECKSUM_MISMATCH result' do
        object_dir = "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        file_path = "#{object_dir}/v0001/data/content/eric-smith-dissertation-augmented.pdf"
        expect(results).to receive(:add_result).with(
          AuditResults::MOAB_FILE_CHECKSUM_MISMATCH, file_path: file_path, version: 1
        )
        cv.send(:validate_signature_catalog_listing)
      end
    end

    context "SC1258_FUR_032a.jpg not on disk, but it's entry element exists in signatureCatalog.xml" do
      let(:druid) { 'tt222tt2222' }
      let(:endpoint_name) { 'fixture_sr3' }

      before { allow(AuditResults).to receive(:new).and_return(results) }

      it 'adds a FILE_NOT_IN_MOAB error' do
        object_dir = "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        manifest_file_path = "#{object_dir}/v0003/manifests/signatureCatalog.xml"
        file_path = "#{object_dir}/v0001/data/content/SC1258_FUR_032a.jpg"
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_MOAB, manifest_file_path: manifest_file_path, file_path: file_path
        )
        cv.send(:validate_signature_catalog_listing)
      end
    end

    context 'signatureCatalog.xml not found in moab' do
      let(:druid) { 'zz333vv3333' }
      let(:endpoint_name) { 'fixture_sr3' }

      before { allow(AuditResults).to receive(:new).and_return(results) }

      it 'adds a MANIFEST_NOT_IN_MOAB error' do
        object_dir = "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        expect(results).to receive(:add_result).with(
          AuditResults::SIGNATURE_CATALOG_NOT_IN_MOAB, signature_catalog_path: "#{object_dir}/v0002/manifests/signatureCatalog.xml"
        )
        cv.send(:validate_signature_catalog_listing)
      end
    end

    context 'cannot parse signatureCatalog.xml' do
      let(:druid) { 'xx444xx4444' }
      let(:endpoint_name) { 'fixture_sr3' }

      before { allow(AuditResults).to receive(:new).and_return(results) }

      it 'adds an INVALID_MANIFEST error' do
        object_dir = "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        expect(results).to receive(:add_result).with(
          AuditResults::INVALID_MANIFEST, manifest_file_path: "#{object_dir}/v0001/manifests/signatureCatalog.xml"
        )
        cv.send(:validate_signature_catalog_listing)
      end
    end
  end

  context '#validate_checksums' do
    context 'passes checksum validation' do
      let(:druid) { 'bz514sm9647' }
      let(:endpoint_name) { 'fixture_sr1' }

      it 'returns a positive result for a pres_copy' do
        cv.validate_checksums
        expect(cv.results.result_array.first).to have_key(:moab_checksum_valid)
      end

      [
        PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS,
        PreservedCopy::INVALID_MOAB_STATUS,
        PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS,
        PreservedCopy::INVALID_CHECKSUM_STATUS,
        PreservedCopy::VALIDITY_UNKNOWN_STATUS
      ].each do |initial_status|
        it "sets status to OK_STATUS if it was previously #{initial_status}" do
          pres_copy.status = initial_status
          pres_copy.save!
          expect { cv.validate_checksums }.to change { pres_copy.status }.to PreservedCopy::OK_STATUS
          expect(pres_copy.reload.status).to eq PreservedCopy::OK_STATUS
        end
      end

      it "leaves status of OK_STATUS as-is" do
        pres_copy.status = PreservedCopy::OK_STATUS
        pres_copy.save!
        expect { cv.validate_checksums }.not_to(change { pres_copy.status })
        expect(pres_copy.reload.status).to eq PreservedCopy::OK_STATUS
      end

      context 'fails other moab validation' do
        context 'version on disk does not match expected version from catalog' do
          before do
            pres_copy.version = 4 # this is one greater than the version on disk for bz514sm9647
            pres_copy.save!
          end

          [
            PreservedCopy::OK_STATUS,
            PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS,
            PreservedCopy::INVALID_MOAB_STATUS,
            PreservedCopy::INVALID_CHECKSUM_STATUS,
            PreservedCopy::VALIDITY_UNKNOWN_STATUS
          ].each do |initial_status|
            it "sets status to UNEXPECTED_VERSION_ON_STORAGE_STATUS if it was previously #{initial_status}" do
              pres_copy.status = initial_status
              pres_copy.save!
              expect { cv.validate_checksums }.to change { pres_copy.status }.to PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
              expect(cv.results.contains_result_code?(AuditResults::UNEXPECTED_VERSION)).to be true
              expect(pres_copy.reload.status).to eq PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
            end
          end

          it 'leaves status as UNEXPECTED_VERSION_ON_STORAGE_STATUS if pres copy started in that state' do
            pres_copy.status = PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
            pres_copy.save!
            expect { cv.validate_checksums }.not_to(change { pres_copy.status })
            expect(cv.results.contains_result_code?(AuditResults::UNEXPECTED_VERSION)).to be true
            expect(pres_copy.reload.status).to eq PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
          end
        end

        context '#moab_validation_errors indicates there are structural errors' do
          before do
            allow(cv).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
          end

          [
            PreservedCopy::OK_STATUS,
            PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS,
            PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS,
            PreservedCopy::INVALID_CHECKSUM_STATUS,
            PreservedCopy::VALIDITY_UNKNOWN_STATUS
          ].each do |initial_status|
            it "sets status as INVALID_MOAB_STATUS if it was #{initial_status}" do
              pres_copy.status = initial_status
              pres_copy.save!
              expect { cv.validate_checksums }.to change { pres_copy.status }.to PreservedCopy::INVALID_MOAB_STATUS
              expect(pres_copy.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
            end
          end

          it 'leaves status as INVALID_MOAB_STATUS if pres copy started in that state' do
            pres_copy.status = PreservedCopy::INVALID_MOAB_STATUS
            pres_copy.save!
            expect { cv.validate_checksums }.not_to(change { pres_copy.status })
            expect(pres_copy.reload.status).to eq PreservedCopy::INVALID_MOAB_STATUS
          end
        end
      end
    end

    context 'fails checksum validation' do
      it 'returns error codes for a pres_copy' do
        cv.validate_checksums
        expect(cv.results.result_array.first).to have_key(:file_not_in_manifest)
      end

      [
        PreservedCopy::OK_STATUS,
        PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS,
        PreservedCopy::INVALID_MOAB_STATUS,
        PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS,
        PreservedCopy::VALIDITY_UNKNOWN_STATUS
      ].each do |initial_status|
        it "sets PreservedCopy status to INVALID_CHECKSUM_STATUS if it was initially #{initial_status}" do
          pres_copy.status = initial_status
          expect { cv.validate_checksums }.to change { pres_copy.status }.to PreservedCopy::INVALID_CHECKSUM_STATUS
        end
      end

      it 'leaves PreservedCopy status as INVALID_CHECKSUM_STATUS if it already was' do
        pres_copy.status = PreservedCopy::INVALID_CHECKSUM_STATUS
        expect { cv.validate_checksums }.not_to(change { pres_copy.status })
      end

      context 'fails other moab validation' do
        context 'version on disk does not match expected version from catalog' do
          before do
            pres_copy.version = 4 # this is one greater than the version on disk for bz514sm9647
            pres_copy.save!
          end

          [
            PreservedCopy::OK_STATUS,
            PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS,
            PreservedCopy::INVALID_MOAB_STATUS,
            PreservedCopy::VALIDITY_UNKNOWN_STATUS,
            PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS
          ].each do |initial_status|
            it "sets status to INVALID_CHECKSUM_STATUS if it was previously #{initial_status}" do
              pres_copy.status = initial_status
              pres_copy.save!
              expect { cv.validate_checksums }.to change { pres_copy.status }.to PreservedCopy::INVALID_CHECKSUM_STATUS
              expect(pres_copy.reload.status).to eq PreservedCopy::INVALID_CHECKSUM_STATUS
            end
          end

          it 'leaves status as INVALID_CHECKSUM_STATUS if pres copy started in that state' do
            pres_copy.status = PreservedCopy::INVALID_CHECKSUM_STATUS
            pres_copy.save!
            expect { cv.validate_checksums }.not_to(change { pres_copy.status })
            expect(pres_copy.reload.status).to eq PreservedCopy::INVALID_CHECKSUM_STATUS
          end
        end

        context '#moab_validation_errors indicates there are structural errors' do
          before do
            allow(cv).to receive(:moab_validation_errors).and_return([{ Moab::StorageObjectValidator::MISSING_DIR => 'err msg' }])
          end

          [
            PreservedCopy::OK_STATUS,
            PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS,
            PreservedCopy::UNEXPECTED_VERSION_ON_STORAGE_STATUS,
            PreservedCopy::VALIDITY_UNKNOWN_STATUS,
            PreservedCopy::INVALID_MOAB_STATUS
          ].each do |initial_status|
            it "sets status as INVALID_CHECKSUM_STATUS if it was #{initial_status}" do
              pres_copy.status = initial_status
              pres_copy.save!
              expect { cv.validate_checksums }.to change { pres_copy.status }.to PreservedCopy::INVALID_CHECKSUM_STATUS
              expect(pres_copy.reload.status).to eq PreservedCopy::INVALID_CHECKSUM_STATUS
            end
          end

          it 'leaves status as INVALID_CHECKSUM_STATUS if pres copy started in that state' do
            pres_copy.status = PreservedCopy::INVALID_CHECKSUM_STATUS
            pres_copy.save!
            expect { cv.validate_checksums }.not_to(change { pres_copy.status })
            expect(pres_copy.reload.status).to eq PreservedCopy::INVALID_CHECKSUM_STATUS
          end
        end
      end
    end

    context 'reports resulsts ' do
      it 'calls AuditResults.report_results' do
        expect(cv.results).to receive(:report_results)
        cv.validate_checksums
      end
    end

    context 'deals with transactions properly' do
      let(:druid) { 'bz514sm9647' } # should pass validation
      let(:endpoint_name) { 'fixture_sr1' }

      before do
        # would result in a status update if the save succeeded
        pres_copy.status = PreservedCopy::ONLINE_MOAB_NOT_FOUND_STATUS
        pres_copy.save!

        # do this second since we save! as part of setup
        allow(pres_copy).to receive(:save!).and_raise(ActiveRecord::ConnectionTimeoutError)
      end

      it 'does not re-throw an ActiveRecord error we know how to deal with' do
        expect { cv.validate_checksums }.not_to raise_error
      end

      it 'has a result code indicating the update failed' do
        cv.validate_checksums
        expect(cv.results.contains_result_code?(AuditResults::DB_UPDATE_FAILED)).to eq true
      end

      it 'does not have a result code indicating the update happened' do
        cv.validate_checksums
        expect(cv.results.contains_result_code?(AuditResults::PC_STATUS_CHANGED)).to eq false
      end
    end
  end

  context '#flag_unexpected_data_files' do
    let(:druid) { 'bj102hs9687' }
    let(:endpoint_name) { 'fixture_sr1' }

    it 'calls validate_against_signature_catalog on each of the data_files' do
      # for easier reading, we assume data_files has a smaller return value
      files = ["#{object_dir}/v0001/data/metadata/contentMetadata.xml"]
      expect(cv).to receive(:data_files).and_return(files)
      allow(cv).to receive(:validate_against_signature_catalog)
      cv.send(:flag_unexpected_data_files)
      files.each do |file|
        expect(cv).to have_received(:validate_against_signature_catalog).with(file)
      end
      expect(cv).to have_received(:validate_against_signature_catalog).exactly(files.size).times
    end

    context 'files are on disk but not present in signatureCatalog.xml' do
      let(:druid) { 'zz555zz5555' }
      let(:endpoint_name) { 'fixture_sr3' }

      before { allow(AuditResults).to receive(:new).and_return(results) }

      it 'adds a FILE_NOT_IN_SIGNATURE_CATALOG error' do
        object_dir = "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        content_file_path = "#{object_dir}/v0001/data/content/not_in_sigcat.txt"
        metadata_file_path = "#{object_dir}/v0001/data/metadata/also_not_in_sigcat.txt"
        nested_file_path = "#{object_dir}/v0001/data/content/unexpected/another_not_in_sigcat.txt"
        signature_catalog_path = "#{object_dir}/v0002/manifests/signatureCatalog.xml"
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_SIGNATURE_CATALOG, file_path: content_file_path, signature_catalog_path: signature_catalog_path
        )
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_SIGNATURE_CATALOG, file_path: metadata_file_path, signature_catalog_path: signature_catalog_path
        )
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_SIGNATURE_CATALOG, file_path: nested_file_path, signature_catalog_path: signature_catalog_path
        )
        cv.send(:flag_unexpected_data_files)
      end
    end
  end

  context '#validate_signature_catalog' do
    let(:druid) { 'bj102hs9687' }
    let(:endpoint_name) { 'fixture_sr1' }

    it 'calls validate_signature_catalog_listing' do
      expect(cv).to receive(:validate_signature_catalog_listing)
      cv.validate_signature_catalog
    end

    it 'calls flag_unexpected_data_content_files' do
      expect(cv).to receive(:flag_unexpected_data_files)
      cv.validate_signature_catalog
    end

    context 'file or directory does not exist' do
      let(:druid) { 'yy000yy0000' }
      let(:endpoint_name) { 'fixture_sr2' }
      let(:results) { instance_double(AuditResults, report_results: nil, :check_name= => nil) }

      it 'adds error code and continues executing' do
        allow(results).to receive(:add_result)
        allow(cv).to receive(:results).and_return(results)
        cv.validate_signature_catalog
        expect(results).to have_received(:add_result).with(
          AuditResults::SIGNATURE_CATALOG_NOT_IN_MOAB, anything
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
      cv.validate_checksums
    end

    it 'defaults to md5 only' do
      expect(Digest::MD5).to receive(:new).and_call_original.at_least(:once)
      expect(Digest::SHA1).not_to receive(:new).and_call_original
      expect(Digest::SHA2).not_to receive(:new).and_call_original
      cv.validate_checksums
    end

    it 'sha256 only' do
      allow(Moab::Config).to receive(:checksum_algos).and_return([:sha256])
      expect(Digest::MD5).not_to receive(:new).and_call_original
      expect(Digest::SHA1).not_to receive(:new).and_call_original
      expect(Digest::SHA2).to receive(:new).and_call_original.at_least(:once)
      cv.validate_checksums
    end
  end
end
