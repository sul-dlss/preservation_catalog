require 'rails_helper'
require_relative "../../../lib/audit/checksum.rb"
# FIXME: remove this rubocop once we start writing tests
# rubocop:disable RSpec/RepeatedExample
# TODO: implement this;  we begin with a placeholder

RSpec.describe Checksum do

  describe ".validate_disk" do
    described_class.validate_disk('2018-02-05 21:37:23 UTC', 'services-disk04', 'MD5')
    skip 'we should figure out what they are and test them'
  end

  describe ".validate_disk_profiled" do
    let(:subject) { described_class.validate_disk_profiled(Time.now.utc, 'services-disk04', 'MD5') }

    it "spins up a profiler, calling profiling and printing methods on it" do
      mock_profiler = instance_double(Profiler)
      expect(Profiler).to receive(:new).and_return(mock_profiler)
      expect(mock_profiler).to receive(:prof)
      expect(mock_profiler).to receive(:print_results_flat).with('CV_checksum_validation_on_dir')
      subject
    end

    it "calls .validate_disk" do
      expect(described_class).to receive(:validate_disk)
      subject
    end
  end

  describe ".validate_disk_all_endpoints" do
    it 'calls validate_disk once per endpoint' do
      described_class.validate_disk_all_endpoints('2018-02-05 21:37:23 UTC', 'MD5')
      skip 'we should figure out what they are and test them'
    end

    it 'calls validate_disk with the right arguments' do
      described_class.validate_disk_all_endpoints('2018-02-05 21:37:23 UTC', 'MD5')
      skip 'we should figure out what they are and test them'
    end
  end

  describe ".validate_disk_all_endpoints_profiled" do
    let(:subject) { described_class.validate_disk_all_endpoints_profiled(Time.now.utc, 'MD5') }

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
