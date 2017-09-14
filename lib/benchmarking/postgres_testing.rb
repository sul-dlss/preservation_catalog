# rails runner postgres_testing.rb
require 'benchmark'
require 'logger'
logger = Logger.new('log/benchmark.log')

at_exit do
  logger.info "Benchmarking stopped at #{Time.now.getlocal}"
end

logger.info "#{__FILE__} is running at #{Time.now.getlocal}"

pcc_app_home = '/opt/app/pcc/preservation_core_catalog'
revisions_log = "#{pcc_app_home}/revisions.log"
remote_test_data_dir = "#{pcc_app_home}/testdata"
test_data_file = 'all_vols.out.201703270939.sorted'
remote_test_data = "#{remote_test_data_dir}/#{test_data_file}"

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

# get the test data
remote_test_file_exists = File.file?(remote_test_data)
local_test_file_exists = File.file?(test_data_file)
if remote_test_file_exists
  test_data_lines = File.readlines(remote_test_data)
elsif local_test_file_exists
  # assume file is in this directory
  test_data_lines = File.readlines(test_data_file)
else
  logger.warn "I can't find your test data!"
end

moab_array = []

test_data_lines.each_with_index do |line, _index|
  moab = {}
  line = line.split(' ')
  moab[:id] = line[0]
  moab[:size] = 250
  moab[:current_version] = line[1]
  moab_array << moab
end

time_to_populate_db = Benchmark.realtime do
  moab_array.each do |moab|
    PreservedObject.create!(
      druid: moab[:id],
      size: moab[:size],
      current_version: moab[:current_version]
    )
  end
end

number_of_records = moab_array.count
loading_rate = number_of_records / time_to_populate_db.round(2)
logger.info "It took #{time_to_populate_db} seconds to populate the database"
logger.info "There are #{moab_array.count} records in the database"
logger.info "The process loaded #{loading_rate} records per second"
