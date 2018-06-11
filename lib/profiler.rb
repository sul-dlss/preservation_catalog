# adapted from argo
# takes a block of code, starts the profiler, runs the code, then
# stops the profiler and returns the results of the profiling.
# @example usage
#  profiler = Profiler.new
#  profiler.prof { MoabToCatalog.seed_catalog_for_dir(storage_dir) }
#  profiler.print_results_flat(out_file_id)
class Profiler
  attr_accessor :results

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
