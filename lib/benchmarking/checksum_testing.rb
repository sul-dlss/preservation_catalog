# rubocop:disable Metrics/LineLength, Lint/AssignmentInCondition, Rails/Output
# Script that benchmarks checksum calculations.
#
# To run on server, use e.g.
#
#     ruby lib/benchmarking/checksum_testing.rb 524288 /services-disk12/sdr2objects/jf/215/hj/1444/jf215hj1444/v0001/data/content/jf215hj1444_1_pm.mxf

require 'benchmark'
require 'digest'
require 'English'
require 'logger'
require 'pathname'

# 363M test file
# '/services-disk12/sdr2objects/jj/005/xz/0136/jj005xz0136/v0001/data/content/SC1094_s3_b10_f06_Hospital_0001.tif'

# 2.1G test file
# '/services-disk11/sdr2objects/hk/101/hn/8782/hk101hn8782/v0001/data/content/hk101hn8782_b_pm.wav'

# 15G test file
# '/services-disk12/sdr2objects/jf/215/hj/1444/jf215hj1444/v0001/data/content/jf215hj1444_1_pm.mxf'

# 63G test file
# '/services-disk11/sdr2objects/fm/302/rs/8636/fm302rs8636/v0001/data/content/fm302rs8636_pm.mov'

# 100G test file
# '/services-disk11/sdr2objects/gt/173/pv/4208/gt173pv4208/v0001/data/content/gt173pv4208_pm.mov'

# 214G test file
# '/services-disk11/sdr2objects/fj/491/sg/9116/fj491sg9116/v0001/data/content/fj491sg9116_pm.mov'

logger = Logger.new('log/benchmark_checksum.log')
app_home = '/opt/app/pres/preservation_catalog'
revisions_log = "#{app_home}/revisions.log"
buffer_size = ARGV[0].to_i
test_filename = ARGV[1]

at_exit do
  logger.info "Benchmarking stopped at #{Time.now.getlocal}"
end

def clear_io_buffers
  command_result = `sync`
  logger.error "sync failed with message: \"#{command_result}\" and exit status #{$CHILD_STATUS.exitstatus}" unless $CHILD_STATUS.exitstatus.zero
  command_result = `echo 1 > /proc/sys/vm/drop_caches`
  logger.error "drop_caches failed with message: \"#{command_result}\" and exit status #{$CHILD_STATUS.exitstatus}" unless $CHILD_STATUS.exitstatus.zeroa
end

def all_checksums(pathname, buffer_size)
  result = {}
  md5_digest = Digest::MD5.new
  sha1_digest = Digest::SHA1.new
  sha256_digest = Digest::SHA2.new(256)
  pathname.open("r") do |stream|
    while buffer = stream.read(buffer_size)
      md5_digest.update(buffer)
      sha1_digest.update(buffer)
      sha256_digest.update(buffer)
    end
  end
  result['md5'] = md5_digest.hexdigest
  result['sha1'] = sha1_digest.hexdigest
  result['sha256'] = sha256_digest.hexdigest
  result
end

clear_io_buffers
logger.info "#{__FILE__} is running at #{Time.now.getlocal}"
logger.info "I/O buffer size is #{buffer_size}"

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

logger.info "Current test file: #{test_filename}"
all_checksums_result = {}

time_for_all_checksums = Benchmark.realtime do
  all_checksums_result = all_checksums(Pathname.new(test_filename), buffer_size)
end

logger.info "Time taken to compute all checksums: #{time_for_all_checksums}"
logger.info "md5    = #{all_checksums_result['md5']}"
logger.info "sha1   = #{all_checksums_result['sha1']}"
logger.info "sha256 = #{all_checksums_result['sha256']}"
puts "Time taken to compute all checksums: #{time_for_all_checksums}"
puts "md5    = #{all_checksums_result['md5']}"
puts "sha1   = #{all_checksums_result['sha1']}"
puts "sha256 = #{all_checksums_result['sha256']}"

# rubocop:enable Metrics/LineLength, Lint/AssignmentInCondition, Rails/Output
