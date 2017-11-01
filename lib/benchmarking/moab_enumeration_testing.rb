# rails runner moab_enumeration_testing.rb
require 'benchmark'
require 'logger'

##
# simple class for collecting stats on how fast different moab listing methods run.
#
# Usage:
# $ bundle exec rails console # from shell prompt
# > require './lib/benchmarking/moab_enumeration_testing.rb'
# > benchmarker = MoabEnumerationBenchmarker.new
# > benchmarker.benchmark
class MoabEnumerationBenchmarker

  def benchmarked_revision
    app_home = '/opt/app/pres/preservation_catalog'
    revisions_log = "#{app_home}/revisions.log"

    # last line of revisions.log if it exists
    # or else grab current revision
    if File.file?(revisions_log)
      File.readlines(revisions_log).last
    else
      commit = `git rev-parse HEAD`
      "at revision #{commit}"
    end
  end

  def logger
    @logger ||= Logger.new('log/benchmark_moab_enumeration.log')
  end

  def all_results
    @all_results ||= []
  end

  def methods_to_test
    @methods_to_test ||= [:list_moab_druids]
  end

  def storage_dirs
    @storage_dirs ||= Stanford::StorageServices.storage_roots.map do |strg_rt|
      File.join(strg_rt, Moab::Config.storage_trunk)
    end
  end

  def benchmark
    logger.info "MoabEnumerationBenchmarker.benchmark is running at #{Time.now.getlocal}"
    logger.info benchmarked_revision

    methods_to_test.each { |method_name| collect_results_for_method(method_name) }

    logger.info "Benchmarking stopped at #{Time.now.getlocal}"
  end

  # defaults to not listing out all the druids, because on real storage disks, that'll
  # be *lots*, and we probably want to use this for printing
  def to_json(redact_druids = true)
    all_results.map do |result|
      {
        method_name: result[:method_name],
        storage_dir: result[:storage_dir],
        druid_count: redact_druids ? result[:druid_list].length : result[:druid_list],
        elapsed_time: result[:elapsed_time],
        druids_per_second: result[:druids_per_second],
        benchmark: result[:benchmark]
      }
    end
  end

  def to_s(redact_druids = true)
    JSON.pretty_generate(to_json(redact_druids))
  end

  def dump_all_results
    log_and_print to_s
  end

  private

  # this class was initially used for manual benchmarking, where writing a quick msg to stdout is helpful
  # rubocop:disable Rails/Output
  def log_and_print(msg)
    logger.info msg
    puts "#{msg}\n"
  end
  # rubocop:enable Rails/Output

  def collect_results_for_method(method_name)
    storage_dirs.each do |storage_dir|
      dir_result = collect_stats_for_dir(method_name, storage_dir)
      all_results << dir_result
      log_and_print "#{storage_dir}: #{method_name} found "\
        "#{dir_result[:druid_list].length} druids in #{dir_result[:elapsed_time]} s "\
        "(#{dir_result[:druids_per_second]} druids/s)"
    end
  end

  def collect_stats_for_dir(method_name, storage_dir)
    dir_result = { method_name: method_name, storage_dir: storage_dir }
    dir_result[:benchmark] = Benchmark.bm(storage_dir.length + 5) do |x|
      dir_result[:elapsed_time] = x.report("#{method_name}:\n  #{storage_dir}:") do
        dir_result[:druid_list] = Stanford::MoabStorageDirectory.send(method_name, storage_dir)
      end.real
    end
    dir_result[:druids_per_second] = dir_result[:druid_list].length / dir_result[:elapsed_time]
    dir_result
  end
end
