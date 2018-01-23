require_relative '../../../lib/audit/catalog_to_moab.rb'
require_relative '../../load_fixtures_helper.rb'

RSpec.describe CatalogToMoab do
  let(:last_checked_version_b4_date) { (Time.now.utc - 1.day).iso8601 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/moab_storage_trunk' }

  context '.check_version_on_dir' do
    include_context 'fixture moabs in db'
    let(:subject) { described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir) }

    # NOTE: this test will be removed once we test other things
    it 'test_of_load_fixtures_helper (eventually will be testing code for .check_version_on_dir)' do
      subject
    end
    it 'calls .check_catalog_version' do
      expect(described_class).to receive(:check_catalog_version).at_least(3).times
      described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir)
    end
    it 'will not check a PreservedCopy with a future last_version_audit date' do
      expect(described_class).to receive(:check_catalog_version).exactly(6).times
      described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir)
      pc = PreservedCopy.first
      pc.last_version_audit = (Time.now.utc + 1.day).iso8601
      pc.save
      expect(described_class).to receive(:check_catalog_version).exactly(5).times
      described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir)
    end
  end

  context ".check_version_on_dir_profiled" do
    let(:subject) { described_class.check_version_on_dir_profiled(last_checked_version_b4_date, storage_dir) }

    it "spins up a profiler, calling profiling and printing methods on it" do
      mock_profiler = instance_double(Profiler)
      expect(Profiler).to receive(:new).and_return(mock_profiler)
      expect(mock_profiler).to receive(:prof)
      expect(mock_profiler).to receive(:print_results_flat).with('C2M_check_version_on_dir')
      subject
    end
  end

  context '.check_version_all_dirs' do
    let(:subject) { described_class.check_version_all_dirs(last_checked_version_b4_date) }

    it 'calls .check_version_for_dir once per storage root' do
      expect(described_class).to receive(:check_version_on_dir).exactly(Settings.moab.storage_roots.count).times
      subject
    end

    it 'calls check_version_for_dir with the right arguments' do
      Settings.moab.storage_roots.each do |storage_root|
        expect(described_class).to receive(:check_version_on_dir).with(
          last_checked_version_b4_date,
          "#{storage_root[1]}/#{Settings.moab.storage_trunk}"
        )
      end
      subject
    end
  end

  context ".check_version_all_dirs_profiled" do
    let(:subject) { described_class.check_version_all_dirs_profiled(last_checked_version_b4_date) }

    it "spins up a profiler, calling profiling and printing methods on it" do
      mock_profiler = instance_double(Profiler)
      expect(Profiler).to receive(:new).and_return(mock_profiler)
      expect(mock_profiler).to receive(:prof)
      expect(mock_profiler).to receive(:print_results_flat).with('C2M_check_version_all_dirs')
      subject
    end
  end

  context '.check_catalog_version' do
    include_context 'fixture moabs in db'
    let(:druid) { 'bj102hs9687' }
    let(:po) { PreservedObject.find_by(druid: druid) }
    let(:pres_copy) do
      ep = Endpoint.find_by(storage_location: storage_dir).id
      PreservedCopy.find_by(preserved_object: po, endpoint: ep)
    end
    let(:object_dir) { "#{storage_dir}/#{DruidTools::Druid.new(druid).tree.join('/')}" }

    it 'instantiates Moab::StorageObject from druid and storage_dir' do
      expect(Moab::StorageObject).to receive(:new).with(druid, a_string_matching(object_dir)).and_call_original
      described_class.send(:check_catalog_version, pres_copy, nil)
    end

    it 'gets the current version on disk from the Moab::StorageObject' do
      moab = instance_double(Moab::StorageObject)
      allow(Moab::StorageObject).to receive(:new).with(druid, instance_of(String)).and_return(moab)
      expect(moab).to receive(:current_version_id).and_return(3)
      described_class.send(:check_catalog_version, pres_copy, nil)
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
      described_class.send(:check_catalog_version, pres_copy, nil)
    end

    context 'catalog version == moab version (happy path)' do
      it 'adds a VERSION_MATCHES result' do
        pohandler_results = instance_double(PreservedObjectHandlerResults, report_results: nil)
        allow(PreservedObjectHandlerResults).to receive(:new).and_return(pohandler_results)
        expect(pohandler_results).to receive(:add_result).with(
          PreservedObjectHandlerResults::VERSION_MATCHES, 'PreservedCopy'
        )
        described_class.send(:check_catalog_version, pres_copy, nil)
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
        described_class.send(:check_catalog_version, pres_copy, nil)
      end
      it 'calls PreservedObjectHandler.update_version_after_validation' do
        pohandler = instance_double(PreservedObjectHandler)
        expect(PreservedObjectHandler).to receive(:new).and_return(pohandler)
        expect(pohandler).to receive(:update_version_after_validation)
        described_class.send(:check_catalog_version, pres_copy, nil)
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
        described_class.send(:check_catalog_version, pres_copy, nil)
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
