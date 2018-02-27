require 'rails_helper'
require_relative "../../../lib/audit/checksum.rb"
# FIXME: remove this rubocop once we start writing tests
# TODO: implement this;  we begin with a placeholder

RSpec.describe Checksum do
  let(:endpoint_name) { 'fixture_sr3' }

  describe ".validate_disk" do
    described_class.validate_disk('fixture_sr3')
    skip 'we should figure out what they are and test them'
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
      Settings.moab.storage_roots.each do |storage_root|
        expect(described_class).to receive(:validate_disk).with(
          "#{storage_root[1]}/#{Settings.moab.storage_trunk}"
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

end
