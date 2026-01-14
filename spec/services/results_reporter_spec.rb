# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResultsReporter do
  let(:reporter) { described_class.new(results: results) }
  let(:actual_version) { 6 }
  let(:results) { Results.new(druid: druid, actual_version: actual_version, moab_storage_root: ms_root) }
  let(:druid) { 'ab123cd4567' }
  let(:ms_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }

  describe '#report_results' do
    let(:audit_workflow_reporter) { instance_double(ResultsReporters::AuditWorkflowReporter, report_errors: nil, report_completed: nil) }
    let(:event_service_reporter) { instance_double(ResultsReporters::EventServiceReporter, report_errors: nil, report_completed: nil) }
    let(:honeybadger_reporter) { instance_double(ResultsReporters::HoneybadgerReporter, report_errors: nil, report_completed: nil) }
    let(:logger_reporter) { instance_double(ResultsReporters::LoggerReporter, report_errors: nil, report_completed: nil) }

    before do
      allow(ResultsReporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
      allow(ResultsReporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
      allow(ResultsReporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
      allow(ResultsReporters::LoggerReporter).to receive(:new).and_return(logger_reporter)

      results.add_result(Results::INVALID_MOAB, [
                           "Version directory name not in 'v00xx' format: original-v1",
                           'Version v0005: No files present in manifest dir'
                         ])
      results.add_result(Results::MOAB_RECORD_STATUS_CHANGED, old_status: 'invalid_checksum', new_status: 'ok')
    end

    it 'invokes the reporters' do
      reporter.report_results
      expect(audit_workflow_reporter).to have_received(:report_errors)
        .with(druid: druid, version: actual_version, storage_area: ms_root, check_name: nil,
              results: [{ invalid_moab: "Invalid Moab, validation errors: [\"Version directory name not in 'v00xx' " \
                                        'format: original-v1", "Version v0005: No files present in manifest dir"]' }])
      expect(event_service_reporter).to have_received(:report_errors)
        .with(druid: druid, version: actual_version, storage_area: ms_root, check_name: nil,
              results: [{ invalid_moab: "Invalid Moab, validation errors: [\"Version directory name not in 'v00xx' " \
                                        'format: original-v1", "Version v0005: No files present in manifest dir"]' }])
      expect(honeybadger_reporter).to have_received(:report_errors)
        .with(druid: druid, version: actual_version, storage_area: ms_root, check_name: nil,
              results: [{ invalid_moab: "Invalid Moab, validation errors: [\"Version directory name not in 'v00xx' " \
                                        'format: original-v1", "Version v0005: No files present in manifest dir"]' }])
      expect(logger_reporter).to have_received(:report_errors)
        .with(druid: druid, version: actual_version, storage_area: ms_root, check_name: nil,
              results: [{ invalid_moab: "Invalid Moab, validation errors: [\"Version directory name not in 'v00xx' " \
                                        'format: original-v1", "Version v0005: No files present in manifest dir"]' }])

      expect(audit_workflow_reporter).to have_received(:report_completed)
        .with(druid: druid, version: actual_version, storage_area: ms_root, check_name: nil,
              result: { moab_record_status_changed: 'MoabRecord status changed from invalid_checksum to ok' })
      expect(event_service_reporter).to have_received(:report_completed)
        .with(druid: druid, version: actual_version, storage_area: ms_root, check_name: nil,
              result: { moab_record_status_changed: 'MoabRecord status changed from invalid_checksum to ok' })
      expect(honeybadger_reporter).to have_received(:report_completed)
        .with(druid: druid, version: actual_version, storage_area: ms_root, check_name: nil,
              result: { moab_record_status_changed: 'MoabRecord status changed from invalid_checksum to ok' })
      expect(logger_reporter).to have_received(:report_completed)
        .with(druid: druid, version: actual_version, storage_area: ms_root, check_name: nil,
              result: { moab_record_status_changed: 'MoabRecord status changed from invalid_checksum to ok' })
    end
  end
end
