# frozen_string_literal: true

require 'json'
require 'digest'
require 'logger'

# Logs slow queries to a file as reported by ActiveSupport::Notifications
# Only queries annotated with a source will be logged.
# For example, PreservedObject.annotate('source=MoabOnStorageService.num_preserved_objects').count
# Adapted from https://sosedoff.com/2020/02/18/rails-log-slow-queries.html
class SlowQueryLogger
  def initialize(threshold:, output: $stdout)
    @threshold = threshold

    @logger = Logger.new(output)
    @logger.formatter = method(:formatter)
  end

  def call(_name, start, finish, _id, payload)
    sql, source = parse_sql(payload[:sql])
    return unless source
    # Skip transaction start/end statements
    return if sql.match?(/BEGIN|COMMIT|SET|SHOW/)

    duration = duration_for(start, finish)
    return unless duration >= threshold

    data = {
      time: start.iso8601,
      duration_ms: duration,
      source: source,
      query: clean_sql(sql),
      bindings: payload[:type_casted_binds].presence
    }.compact

    logger.info(data)
  end

  private

  attr_reader :logger, :threshold

  def duration_for(start, finish)
    ((finish - start) * 1000).round(0)
  end

  def formatter(_severity, _time, _progname, data)
    "#{JSON.dump(data)}\n"
  end

  def clean_sql(sql)
    sql.strip.gsub(/(^(\s+)?$\n)/, '').gsub('"', "'")
  end

  def parse_sql(sql)
    return unless (matcher = sql.match(%r{(.+) /\* source=(.+) \*/}))

    [matcher[1], matcher[2]]
  end
end
