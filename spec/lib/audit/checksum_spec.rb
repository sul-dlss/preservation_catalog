require 'rails_helper'
require_relative "../../../lib/audit/checksum.rb"
require_relative '../../load_fixtures_helper.rb'

RSpec.describe Checksum do
  let(:endpoint_name) { 'fixture_sr1' }
  let(:limit) { Settings.c2m_sql_limit }

  context '.validate_disk' do
    include_context 'fixture moabs in db'
    let(:subject) { described_class.validate_disk(endpoint_name, limit) }

    context 'when there are PreservedCopies to check' do
      let(:cv_mock) { instance_double(ChecksumValidator) }

      it 'creates an instance and calls #validate_checksums for every result when results are in a single batch' do
        allow(ChecksumValidator).to receive(:new).and_return(cv_mock)
        expect(cv_mock).to receive(:validate_checksums).exactly(3).times
        described_class.validate_disk(endpoint_name, limit)
      end

      it 'creates an instance and calls #validate_checksums on everything in batches' do
        pcs_from_scope = PreservedCopy.by_endpoint_name(endpoint_name).fixity_check_expired
        cv_list = pcs_from_scope.map do |pc|
          ChecksumValidator.new(pc, endpoint_name)
        end
        cv_list.each do |cv|
          allow(ChecksumValidator).to receive(:new).with(cv.preserved_copy, endpoint_name).and_return(cv)
          expect(cv).to receive(:validate_checksums).exactly(1).times.and_call_original
        end
        described_class.validate_disk(endpoint_name, 2)
      end
    end

    context 'when there are no PreservedCopies to check' do
      it 'will not create an instance to call validate_manifest_inventories on' do
        allow(ChecksumValidator).to receive(:new)
        PreservedCopy.all.update(last_checksum_validation: (Time.now.utc + 2.days))
        expect(ChecksumValidator).not_to receive(:new)
        subject
      end
    end
  end

  describe ".validate_disk_profiled" do
    let(:subject) { described_class.validate_disk_profiled('fixture_sr3') }

    it "spins up a profiler, calling profiling and printing methods on it" do
      mock_profiler = instance_double(Profiler)
      expect(Profiler).to receive(:new).and_return(mock_profiler)
      expect(mock_profiler).to receive(:prof)
      expect(mock_profiler).to receive(:print_results_flat).with('CV_checksum_validation_on_endpoint')
      subject
    end

    it "calls .validate_disk" do
      expect(described_class).to receive(:validate_disk)
      subject
    end
  end

  describe ".validate_disk_all_endpoints" do
    let(:subject) { described_class.validate_disk_all_endpoints }

    it 'calls validate_disk once per storage root' do
      expect(described_class).to receive(:validate_disk).exactly(Settings.moab.storage_roots.count).times
      subject
    end

    it 'calls validate_disk with the right arguments' do
      Settings.moab.storage_roots.each_key do |storage_name|
        expect(described_class).to receive(:validate_disk).with(
          storage_name
        )
      end
      subject
    end
  end

  describe ".validate_disk_all_endpoints_profiled" do
    let(:subject) { described_class.validate_disk_all_endpoints_profiled }

    it "spins up a profiler, calling profiling and printing methods on it" do
      mock_profiler = instance_double(Profiler)
      expect(Profiler).to receive(:new).and_return(mock_profiler)
      expect(mock_profiler).to receive(:prof)
      expect(mock_profiler).to receive(:print_results_flat).with('CV_checksum_validation_all_endpoints')
      subject
    end
    it "calls .validate_disk_all_endpoints" do
      expect(described_class).to receive(:validate_disk_all_endpoints)
      subject
    end
  end

  describe ".validate_druid" do
    include_context 'fixture moabs in db'
    it 'creates an instance ancd calls #validate_checksums for one result' do
      druid = 'bz514sm9647'
      cv_mock = instance_double(ChecksumValidator)
      allow(ChecksumValidator).to receive(:new).and_return(cv_mock)
      expect(cv_mock).to receive(:validate_checksums).exactly(1).times
      described_class.validate_druid(druid)
    end
  end
end
