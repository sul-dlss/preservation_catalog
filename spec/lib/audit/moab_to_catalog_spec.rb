require 'rails_helper'
require 'stringio'

RSpec.describe Audit::MoabToCatalog do
  let(:storage_dir) { 'spec/fixtures/storage_root01/sdr2objects' }
  let(:endpoint) { Endpoint.find_by!(storage_location: storage_dir) }
  let(:mock_profiler) do
    prof = instance_double(Profiler, prof: nil)
    allow(Profiler).to receive(:new).and_return(prof)
    prof
  end
  let(:moab) do
    m = instance_double(Moab::StorageObject, object_pathname: storage_dir, :storage_root= => nil)
    allow(Moab::StorageObject).to receive(:new).and_return(m)
    m
  end

  before do
    PreservationPolicy.seed_from_config
    allow(described_class.logger).to receive(:info) # silence STDOUT chatter
    allow(Dor::WorkflowService).to receive(:update_workflow_error_status)
  end

  describe '.logger' do
    let(:logfile) { Rails.root.join('log', 'm2c.log') }

    after { FileUtils.rm_f(logfile) }

    it 'writes to STDOUT and its own log' do
      expect { described_class.logger.debug("foobar") }.to output(/foobar/).to_stdout_from_any_process
      expect(File).to exist(logfile)
    end
  end

  describe ".check_existence_for_all_storage_roots" do
    it 'calls check_existence_for_dir once per storage root' do
      expect(described_class).to receive(:check_existence_for_dir).exactly(HostSettings.storage_roots.entries.count).times
      described_class.check_existence_for_all_storage_roots
    end

    it 'calls check_existence_for_dir with the right arguments' do
      HostSettings.storage_roots.to_h.each_value do |path|
        expect(described_class).to receive(:check_existence_for_dir).with("#{path}/#{Settings.moab.storage_trunk}")
      end
      described_class.check_existence_for_all_storage_roots
    end
  end

  describe ".check_existence_for_all_storage_roots_profiled" do
    it "spins up a profiler, calling profiling and printing methods on it" do
      expect(mock_profiler).to receive(:prof)
      expect(mock_profiler).to receive(:print_results_flat).with('M2C_check_existence_for_all_storage_roots')
      described_class.check_existence_for_all_storage_roots_profiled
    end
  end

  describe ".seed_catalog_for_all_storage_roots" do
    it 'calls seed_catalog_for_dir once per storage root' do
      expect(described_class).to receive(:seed_catalog_for_dir).exactly(HostSettings.storage_roots.entries.count).times
      described_class.seed_catalog_for_all_storage_roots
    end

    it 'calls seed_catalog_for_dir with the right arguments' do
      HostSettings.storage_roots.to_h.each_value do |path|
        expect(described_class).to receive(:seed_catalog_for_dir).with("#{path}/#{Settings.moab.storage_trunk}")
      end
      described_class.seed_catalog_for_all_storage_roots
    end
  end

  describe ".seed_catalog_for_all_storage_roots_profiled" do
    it "spins up a profiler, calling profiling and printing methods on it" do
      expect(mock_profiler).to receive(:prof)
      expect(mock_profiler).to receive(:print_results_flat).with('seed_catalog_for_all_storage_roots')
      described_class.seed_catalog_for_all_storage_roots_profiled
    end
  end

  describe ".check_existence_for_dir" do
    it "calls 'find_moab_paths' with appropriate argument" do
      expect(Stanford::MoabStorageDirectory).to receive(:find_moab_paths).with(storage_dir)
      described_class.check_existence_for_dir(storage_dir)
    end

    it 'gets moab size and current version from Moab::StorageObject' do
      expect(moab).to receive(:current_version_id).at_least(1).times
      expect(moab).to receive(:size).at_least(1).times
      expect(Moab::StorageServices).not_to receive(:new)
      described_class.check_existence_for_dir(storage_dir)
    end

    context "(calls check_existence)" do
      let(:expected_argument_list) do
        [
          { druid: 'bj102hs9687', storage_root_current_version: 3 },
          { druid: 'bz514sm9647', storage_root_current_version: 3 },
          { druid: 'jj925bx9565', storage_root_current_version: 2 }
        ]
      end

      before do
        expected_argument_list.each do |arg_hash|
          po_handler = instance_double('PreservedObjectHandler')
          arg_hash[:po_handler] = po_handler
          allow(PreservedObjectHandler).to receive(:new).with(
            arg_hash[:druid],
            arg_hash[:storage_root_current_version],
            instance_of(Integer),
            endpoint
          ).and_return(po_handler)
        end
      end

      it 'calls check_existence' do
        fake_codes = %w[fake_code1 fake_code2]
        expected_argument_list.each do |arg_hash|
          expect(arg_hash[:po_handler]).to receive(:check_existence).and_return(fake_codes)
        end
        # * 3 will magically give us a flat, 6 element array
        expect(described_class.check_existence_for_dir(storage_dir)).to eq(fake_codes * 3)
      end
    end

    it "return correct number of results" do
      expect(described_class.check_existence_for_dir(storage_dir).count).to eq 6
    end
    it "storage directory doesn't exist (misspelling, read write permissions)" do
      allow(Endpoint).to receive(:find_by!).and_return(instance_double(Endpoint))
      expect { described_class.check_existence_for_dir('spec/fixtures/moab_strge_root') }.to raise_error(
        SystemCallError, /No such file or directory/
      )
    end
    it "storage directory exists but it is empty" do
      expect(described_class.check_existence_for_dir('spec/fixtures/empty/sdr2objects')).to eq []
    end
  end

  describe ".check_existence_for_dir_profiled" do
    let(:storage_dir) { "spec/fixtures/storage_root01/sdr2objects" }

    it "spins up a profiler, calling profiling and printing methods on it" do
      expect(mock_profiler).to receive(:prof)
      expect(mock_profiler).to receive(:print_results_flat).with('M2C_check_existence_for_dir')
      described_class.check_existence_for_dir_profiled(storage_dir)
    end
  end

  describe '.check_existence_for_druid' do
    let(:druid) { 'bz514sm9647' }
    let(:results) do
      [{ db_obj_does_not_exist: "PreservedObject db object does not exist" },
       { created_new_object: "added object to db as it did not exist" }]
    end

    it 'finds the relevant moab' do
      expect(Stanford::StorageServices).to receive(:find_storage_object).with(druid).and_call_original
      described_class.check_existence_for_druid(druid)
    end
    it 'finds the correct Endpoint' do
      expect(Endpoint).to receive(:find_by!).with(storage_location: storage_dir)
      described_class.check_existence_for_druid(druid)
    end
    it 'calls pohandler.check_existence' do
      po_handler = instance_double('PreservedObjectHandler')
      expect(PreservedObjectHandler).to receive(:new).with(
        druid,
        3, # current_version
        instance_of(Integer), # size
        endpoint
      ).and_return(po_handler)
      expect(po_handler).to receive(:logger=)
      expect(po_handler).to receive(:check_existence)
      described_class.check_existence_for_druid(druid)
    end
    it 'returns results' do
      expect(described_class.check_existence_for_druid(druid)).to eq results
    end
  end

  describe '.check_existence_for_druid_list' do
    it 'calls MoabToCatalog.check_existence_for_druid once per druid' do
      csv_file_path = 'spec/fixtures/druid_list.csv'
      CSV.foreach(csv_file_path) do |row|
        expect(described_class).to receive(:check_existence_for_druid).with(row.first)
      end
      described_class.check_existence_for_druid_list(csv_file_path)
    end
  end

  describe ".seed_catalog_for_dir" do
    it "calls 'find_moab_paths' with appropriate argument" do
      expect(Stanford::MoabStorageDirectory).to receive(:find_moab_paths).with(storage_dir)
      described_class.seed_catalog_for_dir(storage_dir)
    end

    it 'gets moab size and current version from Moab::StorageObject' do
      expect(moab).to receive(:size).at_least(1).times
      expect(moab).to receive(:current_version_id).at_least(1).times
      expect(Moab::StorageServices).not_to receive(:new)
      described_class.seed_catalog_for_dir(storage_dir)
    end

    context "(creates after validation)" do
      let(:expected_argument_list) do
        [
          { druid: 'bj102hs9687', storage_root_current_version: 3 },
          { druid: 'bz514sm9647', storage_root_current_version: 3 },
          { druid: 'jj925bx9565', storage_root_current_version: 2 }
        ]
      end

      before do
        expected_argument_list.each do |arg_hash|
          po_handler = instance_double('PreservedObjectHandler')
          arg_hash[:po_handler] = po_handler
          allow(PreservedObjectHandler).to receive(:new).with(
            arg_hash[:druid],
            arg_hash[:storage_root_current_version],
            instance_of(Integer),
            endpoint
          ).and_return(po_handler)
        end
      end
      it "call #create_after_validation" do
        expected_argument_list.each do |arg_hash|
          expect(arg_hash[:po_handler]).to receive(:create_after_validation)
        end
        described_class.seed_catalog_for_dir(storage_dir)
      end
    end

    it "return correct number of results" do
      expect(described_class.seed_catalog_for_dir(storage_dir).count).to eq 3
    end
    it "storage directory doesn't exist (misspelling, read write permissions)" do
      allow(Endpoint).to receive(:find_by!).and_return(instance_double(Endpoint))
      expect { described_class.check_existence_for_dir('spec/fixtures/moab_strge_root') }.to raise_error(
        SystemCallError, /No such file or directory/
      )
    end
    it "storage directory exists but it is empty" do
      expect(described_class.check_existence_for_dir('spec/fixtures/empty/sdr2objects')).to eq []
    end
  end

  describe ".drop_endpoint" do
    before { described_class.seed_catalog_for_all_storage_roots }

    it 'drops PreservedCopies that correspond to the given endpoint' do
      expect { described_class.drop_endpoint('fixture_sr1') }.to change { PreservedCopy.count }.from(16).to(13)
    end

    it 'drops PreservedObjects that correspond to the given endpoint' do
      expect { described_class.drop_endpoint('fixture_sr1') }.to change { PreservedObject.count }.from(16).to(13)
    end

    it 'rolls back pres obj delete if pres copy cannot be deleted' do
      active_record_double1 = instance_double(ActiveRecord::Relation)
      active_record_double2 = instance_double(ActiveRecord::Relation)
      allow(PreservedObject).to receive(:left_outer_joins).with(:preserved_copies).and_return(active_record_double1)
      allow(active_record_double1).to receive(:where).with(preserved_copies: { id: nil }).and_return(active_record_double2)
      allow(active_record_double2).to receive(:destroy_all).and_raise(ActiveRecord::ActiveRecordError, 'foo')
      expect { described_class.drop_endpoint('fixture_sr1') }.to raise_error(ActiveRecord::ActiveRecordError)
      expect(PreservedCopy.count).to eq 16
      expect(PreservedObject.count).to eq 16
    end
  end

  describe ".populate_endpoint" do
    before { described_class.seed_catalog_for_all_storage_roots }

    it "won't change objects in a fully seeded db" do
      expect { described_class.populate_endpoint('fixture_sr1') }.not_to change { PreservedCopy.count }.from(16)
      expect(PreservedObject.count).to eq 16
    end

    it 're-adds objects for a dropped endpoint' do
      described_class.drop_endpoint('fixture_sr1')
      expect(PreservedObject.count).to eq 13
      expect { described_class.populate_endpoint('fixture_sr1') }.to change { PreservedCopy.count }.from(13).to(16)
      expect(PreservedObject.count).to eq 16
    end
  end

  describe ".populate_endpoint_profiled" do
    it "spins up a profiler, calling profiling and printing methods on it" do
      expect(mock_profiler).to receive(:prof)
      expect(mock_profiler).to receive(:print_results_flat).with('populate_endpoint')
      described_class.populate_endpoint_profiled('fixture_sr1')
    end
  end
end
