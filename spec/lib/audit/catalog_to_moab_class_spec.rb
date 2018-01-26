require_relative '../../../lib/audit/catalog_to_moab.rb'
require_relative '../../load_fixtures_helper.rb'

RSpec.describe CatalogToMoab do
  let(:last_checked_version_b4_date) { (Time.now.utc - 1.day).iso8601 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/moab_storage_trunk' }

  context '.check_version_on_dir' do
    include_context 'fixture moabs in db'
    let(:subject) { described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir) }

    it 'creates an instance and calls #check_catalog_version' do
      c2m_mock = instance_double(described_class)
      allow(described_class).to receive(:new).and_return(c2m_mock)
      expect(c2m_mock).to receive(:check_catalog_version).exactly(3).times
      described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir)
    end
    it 'will not check a PreservedCopy with a future last_version_audit date' do
      c2m_mock = instance_double(described_class)
      allow(described_class).to receive(:new).and_return(c2m_mock)
      expect(c2m_mock).to receive(:check_catalog_version).exactly(3).times
      described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir)
      pc = PreservedCopy.first
      pc.last_version_audit = (Time.now.utc + 1.day).iso8601
      pc.save
      expect(c2m_mock).to receive(:check_catalog_version).exactly(2).times
      described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir)
    end
    it 'checks a PreservedCopy previously audited before one that is not audited' do
      last_checked_version_b4_date = Time.now.utc
      pcs_before_check = PreservedCopy.least_recent_version_audit(last_checked_version_b4_date, storage_dir)
      before_druids = pcs_before_check.map { |pc| pc.preserved_object.druid }
      last_pc = pcs_before_check.last

      described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir)

      last_pc.reload.last_version_audit = (last_pc.last_version_audit - 2.days)
      last_pc.save

      # the test breaks unless we use Time.now.utc next
      pcs_after_check = PreservedCopy.least_recent_version_audit(Time.now.utc, storage_dir)
      after_druids = pcs_after_check.map { |pc| pc.preserved_object.druid }

      expect(before_druids.first).to eq(after_druids.second)
      expect(before_druids.second).to eq(after_druids.third)
      expect(before_druids.third).to eq(after_druids.first)
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
