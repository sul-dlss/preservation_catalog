require 'benchmark'
require 'logger'
require_relative "../audit/moab_to_catalog.rb"
require 'ruby-prof'

logger = Logger.new('log/benchmark_moab_to_catalog.log')
at_exit do # File.open "/tmp/MoabtoCatalog_rubyprof_#{Time.now.getlocal}", 'w' do |file|
  File.open "#{pcc_app_home}/current/log/MoabtoCatalog_rubyprof_#{Time.now.getlocal}", 'w' do |file|
    RubyProf::FlatPrinter.new(@prof).print(file)
  end
  logger.info "Benchmarking stopped at #{Time.now.getlocal}"
end

logger.info "#{__FILE__} is running at #{Time.now.getlocal}"
pcc_app_home = '/opt/app/pcc/preservation_core_catalog'
revisions_log = "#{pcc_app_home}/revisions.log"

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
# storage_dir = 'spec/fixtures/moab_storage_root'
storage_dir = '/services-disk12/sdr2objects'
time_to_check_existence = Benchmark.realtime do
  RubyProf.start
  logger.info "Check for output"
  StorageRootToDB.check_moab_to_catalog_existence(storage_dir)
  @prof = RubyProf.stop
end
logger.info time_to_check_existence.to_s
logger.info "It took #{time_to_check_existence} seconds to check the database w/ online moab"
