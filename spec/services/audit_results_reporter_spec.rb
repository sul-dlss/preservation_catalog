# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AuditResultsReporter do
  let(:reporter) { described_class.new(audit_results: audit_results) }
  let(:actual_version) { 6 }
  let(:audit_results) { Audit::Results.new(druid: druid, actual_version: actual_version, moab_storage_root: ms_root) }
  let(:druid) { 'ab123cd4567' }
  let(:ms_root) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }

  describe '#report_results' do
    let(:audit_workflow_reporter) { instance_double(AuditReporters::AuditWorkflowReporter, report_errors: nil, report_completed: nil) }
    let(:event_service_reporter) { instance_double(AuditReporters::EventServiceReporter, report_errors: nil, report_completed: nil) }
    let(:honeybadger_reporter) { instance_double(AuditReporters::HoneybadgerReporter, report_errors: nil, report_completed: nil) }
    let(:logger_reporter) { instance_double(AuditReporters::LoggerReporter, report_errors: nil, report_completed: nil) }

    before do
      allow(AuditReporters::AuditWorkflowReporter).to receive(:new).and_return(audit_workflow_reporter)
      allow(AuditReporters::EventServiceReporter).to receive(:new).and_return(event_service_reporter)
      allow(AuditReporters::HoneybadgerReporter).to receive(:new).and_return(honeybadger_reporter)
      allow(AuditReporters::LoggerReporter).to receive(:new).and_return(logger_reporter)

      audit_results.add_result(Audit::Results::INVALID_MOAB, [
                                 "Version directory name not in 'v00xx' format: original-v1",
                                 'Version v0005: No files present in manifest dir'
                               ])
      audit_results.add_result(Audit::Results::MOAB_RECORD_STATUS_CHANGED, old_status: 'invalid_checksum', new_status: 'ok')
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
