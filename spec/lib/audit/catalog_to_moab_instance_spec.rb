require_relative '../../../lib/audit/catalog_to_moab.rb'
require_relative '../../load_fixtures_helper.rb'

RSpec.describe CatalogToMoab do
  let(:last_checked_version_b4_date) { (Time.now.utc - 1.day).iso8601 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/moab_storage_trunk' }

  context '#initialize' do
    include_context 'fixture moabs in db'
    let(:druid) { 'bj102hs9687' }
    let(:pres_copy) do
      po = PreservedObject.find_by(druid: druid)
      ep = Endpoint.find_by(storage_location: storage_dir).id
      PreservedCopy.find_by(preserved_object: po, endpoint: ep)
    end

    it 'sets attributes' do
      c2m = described_class.new(pres_copy, storage_dir)
      expect(c2m.preserved_copy).to eq pres_copy
      expect(c2m.storage_dir).to eq storage_dir
    end
  end

  context '#check_catalog_version' do
    include_context 'fixture moabs in db'
    let(:druid) { 'bj102hs9687' }
    let(:pres_copy) do
      po = PreservedObject.find_by(druid: druid)
      ep = Endpoint.find_by(storage_location: storage_dir).id
      PreservedCopy.find_by(preserved_object: po, endpoint: ep)
    end
    let(:object_dir) { "#{storage_dir}/#{DruidTools::Druid.new(druid).tree.join('/')}" }
    let(:c2m) { described_class.new(pres_copy, storage_dir) }

    it 'instantiates Moab::StorageObject from druid and storage_dir' do
      expect(Moab::StorageObject).to receive(:new).with(druid, a_string_matching(object_dir)).and_call_original
      c2m.check_catalog_version
    end

    it 'gets the current version on disk from the Moab::StorageObject' do
      moab = instance_double(Moab::StorageObject)
      allow(Moab::StorageObject).to receive(:new).with(druid, instance_of(String)).and_return(moab)
      expect(moab).to receive(:current_version_id).and_return(3)
      c2m.check_catalog_version
    end

    it 'calls PreservedCopy.update_audit_timestamps' do
      skip 'add this test after #477 is merged'
    end

    it 'calls PreservedCopy.save!' do
      skip 'add this test after #478; update_at is changed ... what else?  and it calls save! ?'
    end

    it 'calls POHandlerResults.report_results' do
      pohandler_results = instance_double(PreservedObjectHandlerResults, add_result: nil)
      allow(PreservedObjectHandlerResults).to receive(:new).and_return(pohandler_results)
      expect(pohandler_results).to receive(:report_results)
      c2m.check_catalog_version
    end

    context 'catalog version == moab version (happy path)' do
      it 'adds a VERSION_MATCHES result' do
        pohandler_results = instance_double(PreservedObjectHandlerResults, report_results: nil)
        allow(PreservedObjectHandlerResults).to receive(:new).and_return(pohandler_results)
        expect(pohandler_results).to receive(:add_result).with(
          PreservedObjectHandlerResults::VERSION_MATCHES, 'PreservedCopy'
        )
        c2m.check_catalog_version
      end
    end

    context 'catalog version < moab version' do
      before do
        moab = instance_double(Moab::StorageObject, size: 666, object_pathname: object_dir)
        allow(Moab::StorageObject).to receive(:new).with(druid, instance_of(String)).and_return(moab)
        allow(moab).to receive(:current_version_id).and_return(4)
      end

      it 'adds an UNEXPECTED_VERSION result' do
        pohandler_results = instance_double(PreservedObjectHandlerResults, report_results: nil)
        expect(pohandler_results).to receive(:add_result).with(
          PreservedObjectHandlerResults::UNEXPECTED_VERSION, 'PreservedCopy'
        )
        allow(pohandler_results).to receive(:add_result).with(any_args)
        allow(PreservedObjectHandlerResults).to receive(:new).and_return(pohandler_results)
        c2m.check_catalog_version
      end
      it 'calls PreservedObjectHandler.update_version_after_validation' do
        pohandler = instance_double(PreservedObjectHandler)
        expect(PreservedObjectHandler).to receive(:new).and_return(pohandler)
        expect(pohandler).to receive(:update_version_after_validation)
        c2m.check_catalog_version
      end
    end

    context 'catalog version > moab version' do
      before do
        moab = instance_double(Moab::StorageObject, size: 666, object_pathname: object_dir)
        allow(Moab::StorageObject).to receive(:new).with(druid, instance_of(String)).and_return(moab)
        allow(moab).to receive(:current_version_id).and_return(2)
      end

      it 'adds an UNEXPECTED_VERSION result' do
        pohandler_results = instance_double(PreservedObjectHandlerResults, report_results: nil)
        expect(pohandler_results).to receive(:add_result).with(
          PreservedObjectHandlerResults::UNEXPECTED_VERSION, 'PreservedCopy'
        )
        allow(pohandler_results).to receive(:add_result).with(any_args)
        allow(PreservedObjectHandlerResults).to receive(:new).and_return(pohandler_results)
        c2m.check_catalog_version
      end
      it 'does moab validation' do
        skip 'add tests after #491'
      end
      it 'updates status' do
        skip 'add tests after #491, #477'
      end
    end
  end
end
