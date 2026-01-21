# frozen_string_literal: true

# Reports results to the Rails log, Honeybadger, Workflow Service, and Event Service.
class ResultsReporter
  def self.report_results(results:, logger: nil)
    new(results: results, logger: logger).report_results
    # This replicates previous behavior of Results.report_results
    results.to_a
  end

  def initialize(results:, logger: nil)
    @results = results
    @logger = logger
  end

  def report_results
    # Report completed
    report_completed

    # Report errors
    report_errors
  end

  private

  attr_reader :results, :logger

  delegate :druid, :moab_storage_root, :check_name, :actual_version, to: :results

  def reporters
    @reporters ||= [
      ResultsReporters::LoggerReporter.new(logger),
      ResultsReporters::HoneybadgerReporter.new,
      ResultsReporters::EventServiceReporter.new
    ].freeze
  end

  def report_errors
    reporters.each do |reporter|
      reporter.report_errors(druid: druid, version: actual_version, storage_area: moab_storage_root, check_name: check_name,
                             results: results.error_results)
    end
  end

  def report_completed
    reporters.each do |reporter|
      results.completed_results.each do |result|
        reporter.report_completed(druid: druid, version: actual_version, storage_area: moab_storage_root, check_name: check_name, result: result)
      end
    end
  end
end
