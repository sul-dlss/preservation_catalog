require 'rails_helper'
require_relative '../../load_fixtures_helper.rb'

RSpec.describe Audit::Checksum do
  before do
    allow(Dor::WorkflowService).to receive(:update_workflow_error_status)
    allow(Dor::WorkflowService).to receive(:update_workflow_status)
    allow(described_class.logger).to receive(:info) # silence STDOUT chatter
  end

  let(:endpoint_name) { 'fixture_sr1' }
  let(:limit) { Settings.c2m_sql_limit }

  describe '.logger' do
    let(:logfile) { Rails.root.join('log', 'cv.log') }

    after { FileUtils.rm_f(logfile) }

    it 'writes to STDOUT and its own log' do
      expect { described_class.logger.debug("foobar") }.to output(/foobar/).to_stdout_from_any_process
      expect(File).to exist(logfile)
    end
  end

  describe '.validate_disk' do
    include_context 'fixture moabs in db'

    it 'enqueues matching PCs for CV check' do
      expect(ChecksumValidationJob).to receive(:perform_later).with(PreservedCopy).exactly(3).times
      described_class.validate_disk(endpoint_name)
    end

    context 'when there are no PreservedCopies to check' do
      it 'will not enqueue PCs' do
        expect(ChecksumValidationJob).not_to receive(:perform_later)
        PreservedCopy.all.update(last_checksum_validation: (Time.now.utc + 2.days))
        described_class.validate_disk(endpoint_name)
      end
    end
  end

  describe ".validate_disk_all_endpoints" do
    it 'calls validate_disk once per storage root' do
      expect(described_class).to receive(:validate_disk).exactly(HostSettings.storage_roots.entries.count).times
      described_class.validate_disk_all_endpoints
    end

    it 'calls validate_disk with the right arguments' do
      HostSettings.storage_roots.to_h.each_key do |storage_name|
        expect(described_class).to receive(:validate_disk).with(storage_name)
      end
      described_class.validate_disk_all_endpoints
    end
  end

  describe ".validate_druid" do
    include_context 'fixture moabs in db'
    it 'creates an instance ancd calls #validate_checksums for every result' do
      druid = 'bz514sm9647'
      pres_copies = PreservedCopy.by_druid(druid)
      cv_list = pres_copies.map do |pc|
        ChecksumValidator.new(pc)
      end
      cv_list.each do |cv|
        allow(ChecksumValidator).to receive(:new).with(cv.preserved_copy).and_return(cv)
        expect(cv).to receive(:validate_checksums).exactly(1).times.and_call_original
      end
      described_class.validate_druid(druid)
    end

    it "logs a debug message" do
      allow(described_class.logger).to receive(:info)
      allow(described_class.logger).to receive(:debug)
      expect(described_class.logger).to receive(:debug).with('Found 0 preserved copies.')
      described_class.validate_druid('xx000xx0500')
    end

    it 'returns the checksum results lists for each PreservedCopy that was checked' do
      checksum_results_lists = described_class.validate_druid('bz514sm9647')
      expect(checksum_results_lists.size).to eq 1 # should just be one PC for the druid
      checksum_results = checksum_results_lists.first
      expect(checksum_results.contains_result_code?(AuditResults::MOAB_CHECKSUM_VALID)).to eq true
    end
  end

  describe ".validate_list_of_druids" do
    it 'calls Checksum.validate_druid once per druid' do
      csv_file_path = 'spec/fixtures/druid_list.csv'
      CSV.foreach(csv_file_path) do |row|
        expect(described_class).to receive(:validate_druid).with(row.first)
      end
      described_class.validate_list_of_druids(csv_file_path)
    end
  end

  describe '.validate_status_root' do
    include_context 'fixture moabs in db'

    context 'when there are PreservedCopies to check' do
      let(:cv_mock) { instance_double(ChecksumValidator) }

      it 'creates an instance and calls #validate_checksums for every result when results are in a single batch' do
        allow(ChecksumValidator).to receive(:new).and_return(cv_mock)
        expect(cv_mock).to receive(:validate_checksums).exactly(3).times
        described_class.validate_status_root('validity_unknown', endpoint_name, limit)
      end

      it 'creates an instance and calls #validate_checksums on everything in batches' do
        pcs_to_process = PreservedCopy.validity_unknown.by_endpoint_name(endpoint_name)
        cv_list = pcs_to_process.map { |pc| ChecksumValidator.new(pc) }
        expect(cv_list.size).to eq 3
        cv_list.each do |cv|
          allow(ChecksumValidator).to receive(:new).with(cv.preserved_copy).and_return(cv)
          expect(cv).to receive(:validate_checksums).exactly(1).times.and_call_original
        end
        described_class.validate_status_root('validity_unknown', endpoint_name, 2)
      end
    end

    context 'when there are no PreservedCopies to check' do
      it 'will not create an instance of ChecksumValidator' do
        expect(ChecksumValidator).not_to receive(:new)
        described_class.validate_status_root('ok', endpoint_name, limit)
      end
    end

    context 'when status given is invalid' do
      it 'raises a NoMethodError' do
        expect { described_class.validate_status_root('foo', endpoint_name, limit) }.to raise_error(NoMethodError, /^undefined method `foo'.*/)
      end
    end

    context 'when endpoint given is invalid' do
      it 'will not validate any objects' do
        expect(ChecksumValidator).not_to receive(:new)
        described_class.validate_status_root('validity_unknown', 'not_an_endpoint', limit)
      end
    end
  end
end
