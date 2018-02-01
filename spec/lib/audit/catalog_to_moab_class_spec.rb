require_relative '../../../lib/audit/catalog_to_moab.rb'
require_relative '../../load_fixtures_helper.rb'

RSpec.describe CatalogToMoab do
  let(:last_checked_version_b4_date) { (Time.now.utc - 1.day).iso8601 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/moab_storage_trunk' }
  let(:limit) { Settings.c2m_sql_limit }

  context '.check_version_on_dir_of_batch' do
    include_context 'fixture moabs in db'
    let(:subject) { described_class.check_version_on_dir_of_batch(last_checked_version_b4_date, storage_dir, limit) }

    it 'creates an instance and calls #check_catalog_version' do
      c2m_mock = instance_double(described_class)
      allow(described_class).to receive(:new).and_return(c2m_mock)
      expect(c2m_mock).to receive(:check_catalog_version).exactly(3).times
      described_class.check_version_on_dir_of_batch(last_checked_version_b4_date, storage_dir, limit)
    end
  end

  context ".check_version_on_dir" do
    include_context 'fixture moabs in db'
    let(:subject) { described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir) }

    it "calls check_version_on_dir_of_batch when there are objects to audit" do
      expect(described_class).to receive(:check_version_on_dir_of_batch).exactly(1).times
      subject
    end

    it "skips calling check_version_on_dir when there are no objects to audit" do
      expect(described_class).not_to receive(:check_version_on_dir_of_batch)
      PreservedCopy.all.update(last_version_audit: (Time.now.utc + 2.days))
      subject
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
