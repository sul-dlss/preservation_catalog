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

    context 'for nil or past last_version_audit dates' do
      let(:last_checked_version_b4_date) { Time.now.utc }
      let(:pcs_before_check) { PreservedCopy.least_recent_version_audit(last_checked_version_b4_date, storage_dir) }

      it 'checks an unaudited PreservedCopy before one that has been audited' do
        before_druids = pcs_before_check.map { |pc| pc.preserved_object.druid }
        last_pc = pcs_before_check.last # last_version_audit is nil

        described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir)

        last_pc.reload.last_version_audit = (last_pc.last_version_audit - 2.days)
        last_pc.save # last_version_audit is no longer nil

        # the test breaks unless we use Time.now.utc next
        pcs_after_check = PreservedCopy.least_recent_version_audit(Time.now.utc, storage_dir)
        after_druids = pcs_after_check.map { |pc| pc.preserved_object.druid }

        expect(before_druids.first).to eq(after_druids.second)
        expect(before_druids.second).to eq(after_druids.third)
        expect(before_druids.third).to eq(after_druids.first)
      end
      it 'processes dates from oldest to newest order' do
        before_druids = pcs_before_check.map { |pc| pc.preserved_object.druid }
        first_pc = pcs_before_check.first
        second_pc = pcs_before_check.second
        last_pc = pcs_before_check.last

        described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir)

        first_pc.reload.last_version_audit = (first_pc.last_version_audit - 1.day)
        first_pc.save
        second_pc.reload.last_version_audit = (second_pc.last_version_audit - 2.days)
        second_pc.save
        last_pc.reload.last_version_audit = (last_pc.last_version_audit - 3.days)
        last_pc.save

        # the test breaks unless we use Time.now.utc next
        pcs_after_check = PreservedCopy.least_recent_version_audit(Time.now.utc, storage_dir)
        after_druids = pcs_after_check.map { |pc| pc.preserved_object.druid }
        expect(before_druids.first).to eq(after_druids.last)
        expect(before_druids.second).to eq(after_druids.second)
        expect(before_druids.last).to eq(after_druids.first)
      end
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
