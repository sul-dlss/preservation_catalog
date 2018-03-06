require_relative '../../app/services/checksum_validator.rb'
require_relative '../load_fixtures_helper.rb'

RSpec.describe ChecksumValidator do
  include_context 'fixture moabs in db'
  let(:endpoint_name) { "fixture_sr3" }
  let(:endpoint) { Endpoint.find_by(endpoint_name: endpoint_name) }
  let(:object_dir) { "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}" }
  let(:pres_copy) do
    po = PreservedObject.find_by(druid: druid)
    PreservedCopy.find_by(preserved_object: po, endpoint: endpoint)
  end

  context '#initialize' do
    let(:druid) { 'zz102hs9687' }

    it 'sets attributes' do
      cv = described_class.new(pres_copy, endpoint_name)
      expect(cv.preserved_copy).to eq pres_copy
      expect(cv.druid).to eq druid
      expect(cv.endpoint).to eq endpoint
      expect(cv.druid_pre).to eq "druid:#{druid}"
      expect(cv.checksum_results).to be_an_instance_of AuditResults
    end
  end

  context '#validate_manifest_inventories' do
    let(:druid) { 'zz102hs9687' }
    let(:cv) { described_class.new(pres_copy, endpoint_name) }

    it 'instantiates moab_storage_object from druid and druid_path' do
      expect(Moab::StorageObject).to receive(:new).with(cv.druid_pre, a_string_matching(object_dir)).and_call_original
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

    it 'calls AuditResults.report_results' do
      results = instance_double(AuditResults, add_result: nil, :actual_version= => nil, :check_name= => nil)
      allow(AuditResults).to receive(:new).and_return(results)
      expect(results).to receive(:report_results)
      cv.validate_manifest_inventories
    end

    context 'file checksums in manifestInventory.xml do not match' do
      let(:druid) { 'zz925bx9565' }

      it 'adds a MOAB_FILE_CHECKSUM_MISMATCH result' do
        object_dir = "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        file_path1 = "#{object_dir}/v0001/manifests/versionAdditions.xml"
        file_path2 = "#{object_dir}/v0002/manifests/versionInventory.xml"
        results = instance_double(AuditResults, report_results: nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(pres_copy, endpoint_name)
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
      let(:druid) { 'zz102hs9687' }

      it 'adds a FILE_NOT_IN_MANIFEST result' do
        manifest_file_path = "#{object_dir}/v0003/manifests/manifestInventory.xml"
        file_path = "#{object_dir}/v0003/manifests/versionInventory.xml"
        results = instance_double(AuditResults, report_results: nil, check_name: nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(pres_copy, endpoint_name)
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_MANIFEST, file_path: a_string_matching(file_path), manifest_file_path: a_string_matching(manifest_file_path)
        )
        cv.validate_manifest_inventories
      end
    end

    context 'file not on disk, but is described in manifestInventory.xml' do
      let(:druid) { 'zz514sm9647' }

      it 'adds a FILE_NOT_IN_MOAB result' do
        object_dir = "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        manifest_file_path = "#{object_dir}/v0003/manifests/manifestInventory.xml"
        file_path = "#{object_dir}/v0003/manifests/versionInventory.xml"
        results = instance_double(AuditResults, report_results: nil, check_name: nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(pres_copy, endpoint_name)
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_MOAB, manifest_file_path: a_string_matching(manifest_file_path), file_path: a_string_matching(file_path)
        )
        cv.validate_manifest_inventories
      end
    end

    context 'manifestInventory.xml not found in Moab' do
      let(:druid) { 'zz628nk4868' }

      it 'adds a MANIFEST_NOT_IN_MOAB' do
        manifest_file_path = "spec/fixtures/checksum_root01/moab_storage_trunk/zz/628/nk/4868/zz628nk4868/v0001/manifests/manifestInventory.xml"
        results = instance_double(AuditResults, report_results: nil, check_name: nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(pres_copy, endpoint_name)
        expect(results).to receive(:add_result).with(
          AuditResults::MANIFEST_NOT_IN_MOAB, manifest_file_path: manifest_file_path
        )
        cv.validate_manifest_inventories
      end
    end

    context 'cannot parse xml file' do
      let(:druid) { 'zz048cw1328' }

      it 'adds an INVALID_MANIFEST' do
        manifest_file_path = "spec/fixtures/checksum_root01/moab_storage_trunk/zz/048/cw/1328/zz048cw1328/v0002/manifests/manifestInventory.xml"
        results = instance_double(AuditResults, report_results: nil, check_name: nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(pres_copy, endpoint_name)
        expect(results).to receive(:add_result).with(
          AuditResults::INVALID_MANIFEST, manifest_file_path: manifest_file_path
        )
        cv.validate_manifest_inventories
      end
    end
  end

  context '#validate_signature_catalog' do
    let(:druid) { 'zz102hs9687' }
    let(:cv) { described_class.new(pres_copy, endpoint_name) }

    it 'instantiates storage_object from druid and druid_path' do
      expect(Moab::StorageObject).to receive(:new).with(cv.druid_pre, a_string_matching(object_dir)).and_call_original
      cv.validate_signature_catalog
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
      cv.validate_signature_catalog
    end

    it 'calls AuditResults.report_results' do
      results = instance_double(AuditResults, add_result: nil, :actual_version= => nil, :check_name= => nil)
      allow(AuditResults).to receive(:new).and_return(results)
      expect(results).to receive(:report_results)
      cv.validate_signature_catalog
    end

    context 'file checksums in singatureCatalog.xml do not match' do
      let(:druid) { 'zz111rr1111' }

      it 'adds a MOAB_FILE_CHECKSUM_MISMATCH result' do
        results = instance_double(AuditResults, report_results: nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(pres_copy, endpoint_name)
        file_path = 'spec/fixtures/checksum_root01/moab_storage_trunk/zz/111/rr/1111/zz111rr1111/v0001/data/content/eric-smith-dissertation-augmented.pdf'
        expect(results).to receive(:add_result).with(
          AuditResults::MOAB_FILE_CHECKSUM_MISMATCH, file_path: file_path, version: 1
        )
        cv.validate_signature_catalog
      end
    end

    context "SC1258_FUR_032a.jpg not on disk, but it's entry element exists in signatureCatalog.xml" do
      let(:druid) { 'tt222tt2222' }

      it 'adds a FILE_NOT_IN_MOAB error' do
        results = instance_double(AuditResults, report_results: nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(pres_copy, endpoint_name)
        manifest_file_path = "spec/fixtures/checksum_root01/moab_storage_trunk/tt/222/tt/2222/tt222tt2222/v0003/manifests/signatureCatalog.xml"
        file_path = 'spec/fixtures/checksum_root01/moab_storage_trunk/tt/222/tt/2222/tt222tt2222/v0001/data/content/SC1258_FUR_032a.jpg'
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_MOAB, manifest_file_path: manifest_file_path, file_path: file_path
        )
        cv.validate_signature_catalog
      end
    end

    context 'signatureCatalog.xml not found in moab' do
      let(:druid) { 'zz333vv3333' }

      it 'adds a MANIFEST_NOT_IN_MOAB error' do
        results = instance_double(AuditResults, report_results: nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(pres_copy, endpoint_name)
        expect(results).to receive(:add_result).with(
          AuditResults::MANIFEST_NOT_IN_MOAB, manifest_file_path: 'spec/fixtures/checksum_root01/moab_storage_trunk/zz/333/vv/3333/zz333vv3333/v0002/manifests/signatureCatalog.xml'
        )
        cv.validate_signature_catalog
      end
    end

    context 'cannot parse signatureCatalog.xml' do
      let(:druid) { 'xx444xx4444' }

      it 'adds an INVALID_MANIFEST error' do
        results = instance_double(AuditResults, report_results: nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(pres_copy, endpoint_name)
        expect(results).to receive(:add_result).with(
          AuditResults::INVALID_MANIFEST, manifest_file_path: 'spec/fixtures/checksum_root01/moab_storage_trunk/xx/444/xx/4444/xx444xx4444/v0001/manifests/signatureCatalog.xml'
        )
        cv.validate_signature_catalog
      end
    end
  end

  context '#validate_checksum' do
    let(:cv) { described_class.new(pres_copy, endpoint_name) }

    context 'passes validation' do
      let(:druid) { 'bj102hs9687' }
      let(:endpoint_name) { 'fixture_sr1' }

      it 'returns a positive result for a pres_copy' do
        cv = described_class.new(pres_copy, endpoint_name)
        cv.validate_checksum
        expect(cv.checksum_results.result_array.first).to have_key(:moab_checksum_valid)
      end
    end

    context 'fails validation' do
      let(:druid) { 'zz102hs9687' }
      let(:endpoint_name) { 'fixture_sr3' }

      it 'returns error codes for a pres_copy' do
        cv = described_class.new(pres_copy, endpoint_name)
        cv.validate_checksum
        expect(cv.checksum_results.result_array.first).to have_key(:file_not_in_manifest)
      end
    end
  end
end
