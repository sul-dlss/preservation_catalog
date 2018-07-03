require 'rails_helper'
require_relative '../../load_fixtures_helper.rb'

RSpec.describe Audit::CatalogToMoab do
  let(:last_checked_version_b4_date) { (Time.now.utc - 1.day).iso8601 }
  let(:storage_dir) { 'spec/fixtures/storage_root01/sdr2objects' }
  let(:limit) { Settings.c2m_sql_limit }

  describe '.logger' do
    let(:logfile) { Rails.root.join('log', 'c2m.log') }

    after { FileUtils.rm_f(logfile) }

    it 'writes to STDOUT and its own log' do
      expect { described_class.logger.debug("foobar") }.to output(/foobar/).to_stdout_from_any_process
      expect(File).to exist(logfile)
    end
  end

  before { allow(described_class.logger).to receive(:info) } # silence STDOUT chatter

  context '.check_version_on_dir' do
    include_context 'fixture moabs in db'
    let(:subject) { described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir, limit) }

    context 'when there are PreservedCopies to check' do
      let(:c2m_mock) { instance_double(described_class) }

      it 'creates an instance and calls #check_catalog_version for every result when results are in a single batch' do
        allow(described_class).to receive(:new).and_return(c2m_mock)
        expect(c2m_mock).to receive(:check_catalog_version).exactly(3).times
        described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir, limit)
      end

      it 'creates an instance and calls #check_catalog_version on everything in batches' do
        # note that there are 3 objects to be processed, and we are setting batch limit to 2,
        # and we are ensuring that we call #check_catalog_version on all 3 objects.

        # we must set up all the described_class instance objects ahead of any process calling CatalogToMoab.new
        pcs_from_scope =
          PreservedCopy.least_recent_version_audit(last_checked_version_b4_date).by_storage_location(storage_dir)
        c2m_list = pcs_from_scope.map do |pc|
          described_class.new(pc, storage_dir)
        end
        c2m_list.each do |c2m|
          allow(described_class).to receive(:new).with(c2m.preserved_copy, storage_dir).and_return(c2m)
          expect(c2m).to receive(:check_catalog_version).exactly(1).times.and_call_original
        end
        described_class.check_version_on_dir(last_checked_version_b4_date, storage_dir, 2)
      end
    end

    context 'when there are no PreservedCopies to check' do
      it 'will not create an instance to call check_catalog_version on' do
        allow(described_class).to receive(:new)
        PreservedCopy.all.update(last_version_audit: (Time.now.utc + 2.days))
        expect(described_class).not_to receive(:new)
        subject
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
      expect(described_class).to receive(:check_version_on_dir).exactly(HostSettings.storage_roots.entries.count).times
      subject
    end

    it 'calls check_version_for_dir with the right arguments' do
      HostSettings.storage_roots.each do |storage_root|
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
