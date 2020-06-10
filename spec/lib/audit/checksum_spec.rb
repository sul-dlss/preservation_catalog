# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Audit::Checksum do
  let(:root_name) { 'fixture_sr1' }
  let(:logger_double) { instance_double(ActiveSupport::Logger, info: nil, add: nil, debug: nil, warn: nil) }

  before do
    allow(WorkflowReporter).to receive(:report_error)
    allow(WorkflowReporter).to receive(:report_completed)
    allow(described_class).to receive(:logger).and_return(logger_double) # silence log output
  end

  describe '.logger' do
    let(:logfile) { Rails.root.join('log', 'cv.log') }

    before { allow(described_class).to receive(:logger).and_call_original } # undo silencing for 1 test

    after { FileUtils.rm_f(logfile) }

    it 'writes to STDOUT and its own log' do
      expect { described_class.logger.debug('foobar') }.to output(/foobar/).to_stdout_from_any_process
      expect(File).to exist(logfile)
    end
  end

  describe '.validate_druid' do
    let!(:po) { create(:preserved_object_fixture, druid: 'bz514sm9647') }

    it 'creates an instance ancd calls #validate_checksums for every result' do
      po.complete_moabs.find_each do |cm|
        cv = ChecksumValidator.new(cm)
        allow(ChecksumValidator).to receive(:new).with(cv.complete_moab).and_return(cv)
        expect(cv).to receive(:validate_checksums).once.and_call_original
      end
      described_class.validate_druid(po.druid)
    end

    it 'logs a debug message' do
      expect(described_class.logger).to receive(:debug).with('Found 0 complete moabs.')
      described_class.validate_druid('xx000xx0500')
    end

    it 'returns the checksum results lists for each CompleteMoab that was checked' do
      checksum_results_lists = described_class.validate_druid('bz514sm9647')
      expect(checksum_results_lists.size).to eq 1 # should just be one PC for the druid
      checksum_results = checksum_results_lists.first
      expect(checksum_results.contains_result_code?(AuditResults::MOAB_CHECKSUM_VALID)).to eq true
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
    context 'when there are CompleteMoabs to check' do
      before do
        create(:preserved_object_fixture, druid: 'bj102hs9687')
        create(:preserved_object_fixture, druid: 'bz514sm9647')
        create(:preserved_object_fixture, druid: 'jj925bx9565')
      end

      it 'queues a ChecksumValidationJob for each result' do
        msr = MoabStorageRoot.find_by!(name: root_name)
        cm_list = msr.complete_moabs.validity_unknown
        expect(cm_list.size).to eq 3
        cm_list.each do |cm|
          expect(ChecksumValidationJob).to receive(:perform_later).with(cm).once
        end
        described_class.validate_status_root('validity_unknown', root_name)
      end
    end

    context 'when there are no CompleteMoabs to check' do
      it 'will not create an instance of ChecksumValidator' do
        expect(ChecksumValidationJob).not_to receive(:perform_later)
        described_class.validate_status_root('ok', root_name)
      end
    end

    it 'with invalid status, raises StatementInvalid' do
      expect { described_class.validate_status_root('foo', root_name) }.to raise_error(ActiveRecord::StatementInvalid)
    end

    it 'with invalid root_name, raises RecordNotFound' do
      expect { described_class.validate_status_root('ok', 'bad_root') }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
