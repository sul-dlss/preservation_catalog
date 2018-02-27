require_relative '../../app/services/checksum_validator.rb'
require_relative '../load_fixtures_helper.rb'

RSpec.describe ChecksumValidator do
  let(:storage_dir) { "spec/fixtures/checksum_root01/moab_storage_trunk" }
  let(:endpoint) { Endpoint.find_by(storage_location: storage_dir) }
  let(:object_dir) { "#{storage_dir}/#{DruidTools::Druid.new(druid).tree.join('/')}" }

  context '#initialize' do
    it 'sets attributes' do
      druid = 'bj102hs9687'
      cv = described_class.new(druid, storage_dir)
      expect(cv.druid).to eq "druid:#{druid}"
      expect(cv.endpoint).to eq endpoint
      expect(cv.checksum_results).to be_an_instance_of AuditResults
    end
  end

  context '#validate_manifest_inventories' do
    let(:druid) { 'bj102hs9687' }
    let(:cv) { described_class.new(druid, storage_dir) }

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
        object_dir = "#{storage_dir}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        file_path1 = "#{object_dir}/v0001/manifests/versionAdditions.xml"
        file_path2 = "#{object_dir}/v0002/manifests/versionInventory.xml"
        results = instance_double(AuditResults, report_results: nil, :check_name= => nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(druid, storage_dir)
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
        cv = described_class.new(druid, storage_dir)
        expect(results).to receive(:add_result).with(
          AuditResults::FILE_NOT_IN_MANIFEST, file_path: a_string_matching(file_path), manifest_file_path: a_string_matching(manifest_file_path)
        )
        cv.validate_manifest_inventories
      end
    end

    context 'file not on disk, but is described in manifestInventory.xml' do
      it 'adds a FILE_NOT_IN_MOAB result' do
        druid = 'bz514sm9647'
        object_dir = "#{storage_dir}/#{DruidTools::Druid.new(druid).tree.join('/')}"
        manifest_file_path = "#{object_dir}/v0003/manifests/manifestInventory.xml"
        file_path = "#{object_dir}/v0003/manifests/versionInventory.xml"
        results = instance_double(AuditResults, report_results: nil, check_name: nil)
        allow(AuditResults).to receive(:new).and_return(results)
        cv = described_class.new(druid, storage_dir)
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
        cv = described_class.new(druid, storage_dir)
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
        cv = described_class.new(druid, storage_dir)
        expect(results).to receive(:add_result).with(
          AuditResults::INVALID_MANIFEST, manifest_file_path: manifest_file_path
        )
        cv.validate_manifest_inventories
      end
    end
  end
end
