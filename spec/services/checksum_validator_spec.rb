require_relative '../../app/services/checksum_validator.rb'
require_relative '../load_fixtures_helper.rb'

RSpec.describe ChecksumValidator do
  let(:endpoint_name) { "fixture_sr3" }
  let(:endpoint) { Endpoint.find_by(endpoint_name: endpoint_name) }
  let(:object_dir) { "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}" }

  context '#initialize' do
    it 'sets attributes' do
      druid = 'bj102hs9687'
      cv = described_class.new(druid, endpoint_name)
      expect(cv.druid).to eq "druid:#{druid}"
      expect(cv.endpoint).to eq endpoint
      expect(cv.checksum_results).to be_an_instance_of AuditResults
    end
  end

  context '#validate_manifest_inventories' do
    let(:druid) { 'bj102hs9687' }
    let(:cv) { described_class.new(druid, endpoint_name) }

    it 'instantiates moab_storage_object from druid and druid_path' do
      expect(Moab::StorageObject).to receive(:new).with(cv.druid, a_string_matching(object_dir)).and_call_original
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
      it 'adds a MOAB_FILE_CHECKSUM_MISMATCH result' do
        druid = 'jj925bx9565'
        object_dir = "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        file_path1 = "#{object_dir}/v0001/manifests/versionAdditions.xml"
        file_path2 = "#{object_dir}/v0002/manifests/versionInventory.xml"
        results = instance_double(AuditResults, report_results: nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(druid, endpoint_name)
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
      it 'adds a FILE_NOT_IN_MANIFEST result' do
        druid = 'bj102hs9687'
        manifest_file_path = "#{object_dir}/v0003/manifests/manifestInventory.xml"
        file_path = "#{object_dir}/v0003/manifests/versionInventory.xml"
        results = instance_double(AuditResults, report_results: nil, check_name: nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(druid, endpoint_name)
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_MANIFEST, file_path: a_string_matching(file_path), manifest_file_path: a_string_matching(manifest_file_path)
        )
        cv.validate_manifest_inventories
      end
    end

    context 'file not on disk, but is described in manifestInventory.xml' do
      it 'adds a FILE_NOT_IN_MOAB result' do
        druid = 'bz514sm9647'
        object_dir = "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        manifest_file_path = "#{object_dir}/v0003/manifests/manifestInventory.xml"
        file_path = "#{object_dir}/v0003/manifests/versionInventory.xml"
        results = instance_double(AuditResults, report_results: nil, check_name: nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(druid, endpoint_name)
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_MOAB, manifest_file_path: a_string_matching(manifest_file_path), file_path: a_string_matching(file_path)
        )
        cv.validate_manifest_inventories
      end
    end

    context 'manifestInventory.xml not found in Moab' do
      it 'adds a MANIFEST_NOT_IN_MOAB' do
        druid = 'bp628nk4868'
        manifest_file_path = "spec/fixtures/checksum_root01/moab_storage_trunk/bp/628/nk/4868/bp628nk4868/v0001/manifests/manifestInventory.xml"
        results = instance_double(AuditResults, report_results: nil, check_name: nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(druid, endpoint_name)
        expect(results).to receive(:add_result).with(
          AuditResults::MANIFEST_NOT_IN_MOAB, manifest_file_path: manifest_file_path
        )
        cv.validate_manifest_inventories
      end
    end

    context 'cannot parse xml file' do
      it 'adds an INVALID_MANIFEST' do
        druid = 'dc048cw1328'
        manifest_file_path = "spec/fixtures/checksum_root01/moab_storage_trunk/dc/048/cw/1328/dc048cw1328/v0002/manifests/manifestInventory.xml"
        results = instance_double(AuditResults, report_results: nil, check_name: nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(druid, endpoint_name)
        expect(results).to receive(:add_result).with(
          AuditResults::INVALID_MANIFEST, manifest_file_path: manifest_file_path
        )
        cv.validate_manifest_inventories
      end
    end
  end

  context '#validate_signature_catalog' do
    let(:druid) { 'bj102hs9687' }
    let(:cv) { described_class.new(druid, endpoint_name) }

    it 'instantiates storage_object from druid and druid_path' do
      expect(Moab::StorageObject).to receive(:new).with(cv.druid, a_string_matching(object_dir)).and_call_original
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
      it 'adds a MOAB_FILE_CHECKSUM_MISMATCH result' do
        druid = 'rr111rr1111'
        results = instance_double(AuditResults, report_results: nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(druid, endpoint_name)
        file_path = 'spec/fixtures/checksum_root01/moab_storage_trunk/rr/111/rr/1111/rr111rr1111/v0001/data/content/eric-smith-dissertation-augmented.pdf'
        expect(results).to receive(:add_result).with(
          AuditResults::MOAB_FILE_CHECKSUM_MISMATCH, file_path: file_path, version: 1
        )
        cv.validate_signature_catalog
      end
    end

    context "SC1258_FUR_032a.jpg not on disk, but it's entry element exists in signatureCatalog.xml" do
      it 'adds a FILE_NOT_IN_MOAB error' do
        druid = 'tt222tt2222'
        results = instance_double(AuditResults, report_results: nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(druid, endpoint_name)
        manifest_file_path = "spec/fixtures/checksum_root01/moab_storage_trunk/tt/222/tt/2222/tt222tt2222/v0003/manifests/signatureCatalog.xml"
        file_path = 'spec/fixtures/checksum_root01/moab_storage_trunk/tt/222/tt/2222/tt222tt2222/v0001/data/content/SC1258_FUR_032a.jpg'
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_MOAB, manifest_file_path: manifest_file_path, file_path: file_path
        )
        cv.validate_signature_catalog
      end
    end

    context 'signatureCatalog.xml not found in moab' do
      it 'adds a MANIFEST_NOT_IN_MOAB error' do
        druid = 'vv333vv3333'
        results = instance_double(AuditResults, report_results: nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(druid, endpoint_name)
        expect(results).to receive(:add_result).with(
          AuditResults::MANIFEST_NOT_IN_MOAB, manifest_file_path: 'spec/fixtures/checksum_root01/moab_storage_trunk/vv/333/vv/3333/vv333vv3333/v0002/manifests/signatureCatalog.xml'
        )
        cv.validate_signature_catalog
      end
    end

    context 'cannot parse signatureCatalog.xml' do
      it 'adds an INVALID_MANIFEST error' do
        druid = 'xx444xx4444'
        results = instance_double(AuditResults, report_results: nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(druid, endpoint_name)
        expect(results).to receive(:add_result).with(
          AuditResults::INVALID_MANIFEST, manifest_file_path: 'spec/fixtures/checksum_root01/moab_storage_trunk/xx/444/xx/4444/xx444xx4444/v0001/manifests/signatureCatalog.xml'
        )
        cv.validate_signature_catalog
      end
    end
  end

  context '#validate_data_content_files_against_signature_catalog' do
    let(:druid) { 'bj102hs9687' }
    let(:cv) { described_class.new(druid, endpoint_name) }

    it 'calls validate_against_signature_catalog on each of the data_content_files' do
      files = ['spec/fixtures/storage_root01/moab_storage_trunk/bj/102/hs/9687/bj102hs9687/v0001/data/content/eric-smith-dissertation-augmented.pdf',
               'spec/fixtures/storage_root01/moab_storage_trunk/bj/102/hs/9687/bj102hs9687/v0001/data/content/eric-smith-dissertation.pdf']
      expect(cv).to receive(:data_content_files).and_return(files)
      files.each do |file|
        expect(cv).to receive(:validate_against_signature_catalog).with(file)
      end
      cv.validate_data_content_files_against_signature_catalog
    end

    it 'calls AuditResults.report_results' do
      results = instance_double(AuditResults, add_result: nil, :actual_version= => nil, :check_name= => nil)
      allow(AuditResults).to receive(:new).and_return(results)
      expect(results).to receive(:report_results)
      cv.validate_data_content_files_against_signature_catalog
    end

    context 'file is on disk, but not present in signatureCatalog.xml' do
      it 'adds a FILE_NOT_IN_MANIFEST error' do
        druid = 'zz555zz5555'
        file_path = 'spec/fixtures/checksum_root01/moab_storage_trunk/zz/555/zz/5555/zz555zz5555/v0001/data/content/not_in_sigcat.txt'
        manifest_file_path = 'spec/fixtures/checksum_root01/moab_storage_trunk/zz/555/zz/5555/zz555zz5555/v0002/manifests/signatureCatalog.xml'
        results = instance_double(AuditResults, report_results: nil, check_name: nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(druid, endpoint_name)
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_MANIFEST, file_path: file_path, manifest_file_path: manifest_file_path
        )
        cv.validate_data_content_files_against_signature_catalog
      end
    end
  end
end
