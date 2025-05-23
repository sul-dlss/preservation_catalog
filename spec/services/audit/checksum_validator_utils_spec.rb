# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Audit::ChecksumValidatorUtils do
  let(:root_name) { 'fixture_sr1' }
  let(:logger_double) { instance_double(ActiveSupport::Logger, info: nil, add: nil, debug: nil, warn: nil) }
  let(:audit_workflow_reporter) { instance_double(AuditReporters::AuditWorkflowReporter, report_errors: nil, report_completed: nil) }
  let(:event_service_reporter) { instance_double(AuditReporters::EventServiceReporter, report_errors: nil, report_completed: nil) }
  let(:honeybadger_reporter) { instance_double(AuditReporters::HoneybadgerReporter, report_errors: nil, report_completed: nil) }
  let(:logger_reporter) { instance_double(AuditReporters::LoggerReporter, report_errors: nil, report_completed: nil) }

  before do
    allow(described_class.logger).to receive(:info) # silence STDOUT chatter
    allow(AuditReporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
    allow(AuditReporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
    allow(AuditReporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
    allow(AuditReporters::LoggerReporter).to receive(:new).and_return(logger_reporter)
    allow(described_class).to receive(:logger).and_return(logger_double) # silence log output
  end

  describe '.logger' do
    let(:logfile) { Rails.root.join('log', 'audit_checksum_validation.log') }

    before { allow(described_class).to receive(:logger).and_call_original } # undo silencing for 1 test

    after { FileUtils.rm_f(logfile) }

    it 'writes to STDOUT and its own log' do
      expect { described_class.logger.debug('foobar') }.to output(/foobar/).to_stdout_from_any_process
      expect(File).to exist(logfile)
    end
  end

  describe '.validate_druid' do
    let!(:po) { create(:preserved_object_fixture, druid: 'bz514sm9647') }

    it 'creates an instance ancd calls #validate_checksums for MoabRecord' do
      cv = Audit::ChecksumValidationService.new(po.moab_record)
      allow(Audit::ChecksumValidationService).to receive(:new).with(cv.moab_record).and_return(cv)
      allow(cv).to receive(:validate_checksums).and_call_original
      described_class.validate_druid(po.druid)
      expect(cv).to have_received(:validate_checksums)
    end

    it 'logs a debug message' do
      expect(described_class.logger).to receive(:debug).with('Did Not Find MoabRecord in database.')
      described_class.validate_druid('xx000xx0500')
    end

    it 'returns the checksum audit results' do
      checksum_results = described_class.validate_druid('bz514sm9647')
      expect(checksum_results).to be_a(Audit::Results)
      expect(checksum_results.contains_result_code?(Audit::Results::MOAB_CHECKSUM_VALID)).to be true
    end
  end

  describe '.validate_list_of_druids' do
    it 'calls Checksum.validate_druid once per druid' do
      csv_file_path = 'spec/fixtures/druid_list.csv'
      CSV.foreach(csv_file_path) do |row|
        expect(described_class).to receive(:validate_druid).with(row.first)
      end
      described_class.validate_list_of_druids(csv_file_path)
    end
  end

  describe '.validate_status_root' do
    context 'when there are MoabRecords to check' do
      before do
        create(:preserved_object_fixture, druid: 'bj102hs9687')
        create(:preserved_object_fixture, druid: 'bz514sm9647')
        create(:preserved_object_fixture, druid: 'jj925bx9565')
      end

      it 'queues a Audit::ChecksumValidationJob for each result' do
        msr = MoabStorageRoot.find_by!(name: root_name)
        moab_records = msr.moab_records.validity_unknown
        expect(moab_records.size).to eq 3
        moab_records.each do |moab_record|
          expect(Audit::ChecksumValidationJob).to receive(:perform_later).with(moab_record).once
        end
        described_class.validate_status_root('validity_unknown', root_name)
      end
    end

    context 'when there are no MoabRecords to check' do
      it 'does not create an instance of ChecksumValidationService' do
        expect(Audit::ChecksumValidationJob).not_to receive(:perform_later)
        described_class.validate_status_root('ok', root_name)
      end
    end

    it 'with invalid status, raises ArgumentError' do
      expect { described_class.validate_status_root('foo', root_name) }.to raise_error(ArgumentError)
    end

    it 'with invalid root_name, raises RecordNotFound' do
      expect { described_class.validate_status_root('ok', 'bad_root') }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
