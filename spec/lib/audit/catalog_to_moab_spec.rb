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
end
