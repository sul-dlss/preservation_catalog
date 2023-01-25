# frozen_string_literal: true

# Reports audit results to the Rails log, Honeybadger, Workflow Service, and Event Service.
class AuditResultsReporter
  def self.report_results(audit_results:, logger: nil)
    new(audit_results: audit_results, logger: logger).report_results
    # This replicates previous behavior of Audit::Results.report_results
    audit_results.results
  end

  def initialize(audit_results:, logger: nil)
    @audit_results = audit_results
    @logger = logger
  end

  def report_results
    # Report completed
    report_completed

    # Report errors
    report_errors
  end

  private

  attr_reader :audit_results, :logger

  delegate :druid, :moab_storage_root, :check_name, :actual_version, to: :audit_results

  def reporters
    @reporters ||= [
      AuditReporters::LoggerReporter.new(logger),
      AuditReporters::HoneybadgerReporter.new,
      AuditReporters::AuditWorkflowReporter.new,
      AuditReporters::EventServiceReporter.new
    ].freeze
  end

  def report_errors
    reporters.each do |reporter|
      reporter.report_errors(druid: druid, version: actual_version, storage_area: moab_storage_root, check_name: check_name,
                             results: audit_results.error_results)
    end
  end

  def report_completed
    reporters.each do |reporter|
      audit_results.completed_results.each do |result|
        reporter.report_completed(druid: druid, version: actual_version, storage_area: moab_storage_root, check_name: check_name, result: result)
      end
    end
  end
end
