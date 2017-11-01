# bin/rails runner lib/benchmarking/moab_to_catalog_testing.rb

require 'benchmark'
require 'logger'
require_relative "../audit/moab_to_catalog.rb"
require 'ruby-prof'

logger = Logger.new('log/benchmark_moab_to_catalog.log')
at_exit do
  # prof_log_file_name = "{app_home}/current/log/MoabtoCatalog_rubyprof_#{Time.now.getlocal}"
  # prof_log_file_name = "/tmp/MoabtoCatalog_rubyprof_#{Time.now.getlocal}"
  # File.open prof_log_file_name, 'w' do |file|
  #   RubyProf::FlatPrinter.new(@prof).print(file)
  # end
  logger.info "Benchmarking stopped at #{Time.now.getlocal}"
end

logger.info "#{__FILE__} is running at #{Time.now.getlocal}"
app_home = '/opt/app/pres/preservation_catalog'
revisions_log = "#{app_home}/revisions.log"

# last line of revisions.log if it exists
# or else grab current revision
revisions_log_exists = File.file?(revisions_log)
if revisions_log_exists
  last_line = File.readlines(revisions_log).last
  logger.info last_line
else
  commit = `git rev-parse HEAD`
  logger.info "at revision #{commit}"
end
sleep(10)

# this is coming from config/settings.yml and config/initializers
Stanford::StorageServices.storage_roots.each do |storage_root|
  time_to_check_existence = Benchmark.realtime do
    logger.info "Check for output"
    # RubyProf.start
    # when creating add true parameter, and if updating leave blank
    MoabToCatalog.check_existence(File.join(storage_root, Moab::Config.storage_trunk))
    # TODO: haven't actually tested this, but looks to me like this will only get profiling info for the last
    # storage root that was checked.  one way to collect for everything would be to use the start/pause/resume
    # approach described in the RubyProf docs, presumably with a start/pause above this loop, resume/pause in
    # this loop, and @prof = RubyProf.stop after this loop.
    # see https://github.com/ruby-prof/ruby-prof#ruby-prof-convenience-api
    # @prof = RubyProf.stop
  end
  logger.info time_to_check_existence.to_s
  logger.info "It took #{time_to_check_existence} seconds to check the database w/ online moab"
end
