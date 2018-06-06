require 'rails_helper'
require_relative "../../../lib/audit/moab_to_catalog.rb"
require 'stringio'

RSpec.describe MoabToCatalog do
  let(:storage_dir) { 'spec/fixtures/storage_root01/moab_storage_trunk' }
  let(:endpoint) { Endpoint.find_by!(storage_location: storage_dir) }

  before do
    PreservationPolicy.seed_from_config
    allow(described_class.logger).to receive(:info) # silence STDOUT chatter
  end

  describe ".check_existence_for_all_storage_roots" do
    let(:subject) { described_class.check_existence_for_all_storage_roots }

    it 'calls check_existence_for_dir once per storage root' do
      expect(described_class).to receive(:check_existence_for_dir).exactly(HostSettings.storage_roots.entries.count).times
      subject
    end

    it 'calls check_existence_for_dir with the right arguments' do
      HostSettings.storage_roots.each do |storage_root|
        expect(described_class).to receive(:check_existence_for_dir).with("#{storage_root[1]}/#{Settings.moab.storage_trunk}")
      end
      subject
    end
  end

  describe ".check_existence_for_all_storage_roots_profiled" do
    let(:subject) { described_class.check_existence_for_all_storage_roots_profiled }

    it "spins up a profiler, calling profiling and printing methods on it" do
      mock_profiler = instance_double(Profiler)
      expect(Profiler).to receive(:new).and_return(mock_profiler)
      expect(mock_profiler).to receive(:prof)
      expect(mock_profiler).to receive(:print_results_flat).with('M2C_check_existence_for_all_storage_roots')

      subject
    end
  end

  describe ".seed_catalog_for_all_storage_roots" do
    let(:subject) { described_class.seed_catalog_for_all_storage_roots }

    it 'calls seed_catalog_for_dir once per storage root' do
      expect(described_class).to receive(:seed_catalog_for_dir).exactly(HostSettings.storage_roots.entries.count).times
      subject
    end

    it 'calls seed_catalog_for_dir with the right arguments' do
      HostSettings.storage_roots.each do |storage_root|
        expect(described_class).to receive(:seed_catalog_for_dir).with("#{storage_root[1]}/#{Settings.moab.storage_trunk}")
      end
      subject
    end
  end

  describe ".seed_catalog_for_all_storage_roots_profiled" do
    let(:subject) { described_class.seed_catalog_for_all_storage_roots_profiled }

    it "spins up a profiler, calling profiling and printing methods on it" do
      mock_profiler = instance_double(Profiler)

      expect(Profiler).to receive(:new).and_return(mock_profiler)
      expect(mock_profiler).to receive(:prof)
      expect(mock_profiler).to receive(:print_results_flat).with('seed_catalog_for_all_storage_roots')

      subject
    end
  end

  describe ".check_existence_for_dir" do
    let(:subject) { described_class.check_existence_for_dir(storage_dir) }

    it "calls 'find_moab_paths' with appropriate argument" do
      expect(Stanford::MoabStorageDirectory).to receive(:find_moab_paths).with(storage_dir)
      subject
    end

    it 'gets moab current version from Moab::StorageObject' do
      moab = instance_double(Moab::StorageObject)
      allow(moab).to receive(:storage_root=)
      allow(moab).to receive(:object_pathname).and_return(storage_dir)
      allow(moab).to receive(:size)
      expect(moab).to receive(:current_version_id).at_least(1).times
      allow(Moab::StorageObject).to receive(:new).and_return(moab)

      expect(Moab::StorageServices).not_to receive(:new)
      subject
    end

    it 'gets moab size from Moab::StorageObject' do
      moab = instance_double(Moab::StorageObject)
      allow(moab).to receive(:storage_root=)
      allow(moab).to receive(:object_pathname).and_return(storage_dir)
      allow(moab).to receive(:current_version_id)
      expect(moab).to receive(:size).at_least(1).times
      allow(Moab::StorageObject).to receive(:new).and_return(moab)

      expect(Moab::StorageServices).not_to receive(:new)
      subject
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
        expect(subject).to eq(fake_codes * 3)
      end
    end

    it "return correct number of results" do
      expect(subject.count).to eq 6
    end
    it "storage directory doesn't exist (misspelling, read write permissions)" do
      allow(Endpoint).to receive(:find_by!).and_return(instance_double(Endpoint))
      expect { described_class.check_existence_for_dir('spec/fixtures/moab_strge_root') }.to raise_error(
        SystemCallError, /No such file or directory/
      )
    end
    it "storage directory exists but it is empty" do
      storage_dir = 'spec/fixtures/empty/moab_storage_trunk'
      expect(described_class.check_existence_for_dir(storage_dir)).to eq []
    end
  end

  describe ".check_existence_for_dir_profiled" do
    let(:storage_dir) { "spec/fixtures/storage_root01/moab_storage_trunk" }
    let(:subject) { described_class.check_existence_for_dir_profiled(storage_dir) }

    it "spins up a profiler, calling profiling and printing methods on it" do
      mock_profiler = instance_double(Profiler)
      expect(Profiler).to receive(:new).and_return(mock_profiler)
      expect(mock_profiler).to receive(:prof)
      expect(mock_profiler).to receive(:print_results_flat).with('M2C_check_existence_for_dir')

      subject
    end
  end

  describe '.check_existence_for_druid' do
    let(:druid) { 'bz514sm9647' }
    let(:subject) { described_class.check_existence_for_druid(druid) }
    let(:results) do
      [{ db_obj_does_not_exist: "PreservedObject db object does not exist" },
       { created_new_object: "added object to db as it did not exist" }]
    end

    it 'finds the relevant moab' do
      expect(Stanford::StorageServices).to receive(:find_storage_object).with(druid).and_call_original
      subject
    end
    it 'finds the correct Endpoint' do
      expect(Endpoint).to receive(:find_by!).with(storage_location: storage_dir)
      subject
    end
    it 'calls pohandler.check_existence' do
      po_handler = instance_double('PreservedObjectHandler')
      expect(PreservedObjectHandler).to receive(:new).with(
        druid,
        3, # current_version
        instance_of(Integer), # size
        endpoint
      ).and_return(po_handler)
      expect(po_handler).to receive(:check_existence)
      subject
    end
    it 'returns results' do
      expect(subject).to eq results
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
    let(:subject) { described_class.seed_catalog_for_dir(storage_dir) }

    it "calls 'find_moab_paths' with appropriate argument" do
      expect(Stanford::MoabStorageDirectory).to receive(:find_moab_paths).with(storage_dir)
      subject
    end

    it 'gets moab current version from Moab::StorageObject' do
      moab = instance_double(Moab::StorageObject)
      allow(moab).to receive(:storage_root=)
      allow(moab).to receive(:object_pathname).and_return(storage_dir)
      allow(moab).to receive(:size)
      expect(moab).to receive(:current_version_id).at_least(1).times
      allow(Moab::StorageObject).to receive(:new).and_return(moab)

      expect(Moab::StorageServices).not_to receive(:new)
      subject
    end

    it 'gets moab size from Moab::StorageObject' do
      moab = instance_double(Moab::StorageObject)
      allow(moab).to receive(:storage_root=)
      allow(moab).to receive(:object_pathname).and_return(storage_dir)
      allow(moab).to receive(:current_version_id)
      expect(moab).to receive(:size).at_least(1).times
      allow(Moab::StorageObject).to receive(:new).and_return(moab)

      expect(Moab::StorageServices).not_to receive(:new)
      subject
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
        subject
      end
    end

    it "return correct number of results" do
      expect(subject.count).to eq 3
    end
    it "storage directory doesn't exist (misspelling, read write permissions)" do
      allow(Endpoint).to receive(:find_by!).and_return(instance_double(Endpoint))
      expect { described_class.check_existence_for_dir('spec/fixtures/moab_strge_root') }.to raise_error(
        SystemCallError, /No such file or directory/
      )
    end
    it "storage directory exists but it is empty" do
      storage_dir = 'spec/fixtures/empty/moab_storage_trunk'
      expect(described_class.check_existence_for_dir(storage_dir)).to eq []
    end
  end

  describe ".drop_endpoint" do
    let(:subject) { described_class.drop_endpoint('fixture_sr1') }

    before do
      described_class.seed_catalog_for_all_storage_roots
    end

    it 'drops PreservedCopies that correspond to the given endpoint' do
      expect(PreservedCopy.count).to eq 16
      subject
      expect(PreservedCopy.count).to eq 13
    end

    it 'drops PreservedObjects that correspond to the given endpoint' do
      expect(PreservedObject.count).to eq 16
      subject
      expect(PreservedObject.count).to eq 13
    end

    it 'rolls back pres obj delete if pres copy cannot be deleted' do
      active_record_double1 = instance_double(ActiveRecord::Relation)
      active_record_double2 = instance_double(ActiveRecord::Relation)
      allow(PreservedObject).to receive(:left_outer_joins).with(:preserved_copies).and_return(active_record_double1)
      allow(active_record_double1).to receive(:where).with(preserved_copies: { id: nil }).and_return(active_record_double2)
      allow(active_record_double2).to receive(:destroy_all).and_raise(ActiveRecord::ActiveRecordError, 'foo')
      begin
        subject
      rescue
        # Expect this to fail and don't need error handling in the .drop_endpoint class method
        # let subject still run instead of catching ActiveRecordError and stop the execution
      end
      expect(PreservedCopy.count).to eq 16
      expect(PreservedObject.count).to eq 16
    end
  end

  describe ".populate_endpoint" do
    let(:endpoint_name) { 'fixture_sr1' }
    let(:subject) { described_class.populate_endpoint(endpoint_name) }

    before do
      described_class.seed_catalog_for_all_storage_roots
    end

    it "won't change objects in a fully seeded db" do
      subject
      expect(PreservedCopy.count).to eq 16
      expect(PreservedObject.count).to eq 16
    end

    it 're-adds objects for a dropped endpoint' do
      described_class.drop_endpoint(endpoint_name)
      expect(PreservedCopy.count).to eq 13
      expect(PreservedObject.count).to eq 13
      subject
      expect(PreservedCopy.count).to eq 16
      expect(PreservedObject.count).to eq 16
    end
  end

  describe ".populate_endpoint.profiled" do
    let(:root) { 'fixture_sr1' }
    let(:subject) { described_class.populate_endpoint_profiled(root) }

    it "spins up a profiler, calling profiling and printing methods on it" do
      mock_profiler = instance_double(Profiler)
      expect(Profiler).to receive(:new).and_return(mock_profiler)
      expect(mock_profiler).to receive(:prof)
      expect(mock_profiler).to receive(:print_results_flat).with('populate_endpoint')

      subject
    end
  end
end
