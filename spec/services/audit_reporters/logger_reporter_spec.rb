# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditReporters::LoggerReporter do
  let(:druid) { 'ab123cd4567' }
  let(:actual_version) { 6 }
  let(:ms_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
  let(:check_name) { 'FooCheck' }

  before do
    # Force to find so that it is not logged within it block.
    ms_root
    allow(Rails.logger).to receive(:add)
  end

  describe '#report_errors' do
    let(:result1) { { Audit::Results::DB_VERSIONS_DISAGREE => version_not_matched_str } }
    let(:version_not_matched_str) { 'does not match PreservedObject current_version' }

    it 'logs to Rails logger' do
      described_class.new.report_errors(druid: druid, version: actual_version, storage_area: ms_root, check_name: check_name, results: [result1])
      # Logs with check name, druid, storage root, and message
      expect(Rails.logger).to have_received(:add)
        .with(Logger::ERROR, 'FooCheck(ab123cd4567, fixture_sr1) does not match PreservedObject current_version')
    end

    context 'when multiple results' do
      let(:result2) { { Audit::Results::ZIP_PARTS_NOT_CREATED => zip_parts_not_created_str } }
      let(:zip_parts_not_created_str) { 'no zip_parts exist yet for this ZippedMoabVersion' }

      it 'logs each result' do
        described_class.new.report_errors(druid: druid,
                                          version: actual_version,
                                          storage_area: ms_root,
                                          check_name: check_name,
                                          results: [result1, result2])
        expect(Rails.logger).to have_received(:add).with(Logger::ERROR, a_string_matching(version_not_matched_str))
        expect(Rails.logger).to have_received(:add).with(Logger::WARN, a_string_matching(zip_parts_not_created_str))
      end
    end
  end

  describe '#report_completed' do
    let(:result) { { Audit::Results::MOAB_RECORD_STATUS_CHANGED => 'MoabRecord status changed from invalid_moab' } }

    it 'logs to Rails logger' do
      described_class.new.report_completed(druid: druid, version: actual_version, storage_area: ms_root, check_name: check_name, result: result)
      expect(Rails.logger).to have_received(:add)
        .with(Logger::INFO, 'FooCheck(ab123cd4567, fixture_sr1) MoabRecord status changed from invalid_moab')
    end
  end

  describe '.logger_severity_level' do
    it 'DB_VERSIONS_DISAGREE is an ERROR' do
      expect(described_class.new.send(:logger_severity_level, Audit::Results::DB_VERSIONS_DISAGREE)).to eq Logger::ERROR
    end

    it 'DB_OBJ_DOES_NOT_EXIST is WARN' do
      expect(described_class.new.send(:logger_severity_level, Audit::Results::DB_OBJ_DOES_NOT_EXIST)).to eq Logger::WARN
    end

    it 'CREATED_NEW_OBJECT is INFO' do
      expect(described_class.new.send(:logger_severity_level, Audit::Results::CREATED_NEW_OBJECT)).to eq Logger::INFO
    end

    it 'default for unrecognized value is ERROR' do
      expect(described_class.new.send(:logger_severity_level, :whatever)).to eq Logger::ERROR
    end
  end
end
