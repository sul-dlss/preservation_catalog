# adapted from argo
# takes a block of code, starts the profiler, runs the code, then
# stops the profiler and returns the results of the profiling.
# @example usage
#  profiler = Profiler.new
#  profiler.prof { MoabToCatalog.seed_catalog_for_dir(storage_dir) }
#  profiler.print_results_flat(out_file_id)
class Profiler
  attr_accessor :results

  # @param [String] out_file_id, if result printing is desired
  # @param [Block] code to be profiled
  # @return [Profiler] the instance with results
  def self.print_profile(out_file_id = nil)
    raise 'No block given to profile' unless block_given?
    new.tap do |instance|
      instance.prof(&Proc.new) # like a yield, this wraps the block given to re-pass it
      instance.print_results_flat(out_file_id) if out_file_id
    end
  end

  def output_path(out_file_id)
    "log/profile_#{out_file_id}#{Time.now.utc.localtime.strftime('%FT%T')}-flat.txt" # start w/ UTC per rubocop
  end

  def prof
    RubyProf.start
    yield
    @results = RubyProf.stop
  end

  def print_results_flat(out_file_id)
    File.open output_path(out_file_id), 'w' do |file|
      RubyProf::FlatPrinterWithLineNumbers.new(results).print(file)
    end
  end
end
