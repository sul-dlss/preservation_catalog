require_relative '../../lib/profiler.rb'
require 'ruby-prof'

RSpec.describe Profiler do
  let(:profiler) { described_class.new }

  describe '#prof' do
    it 'starts, yields, stops, and returns results' do
      rp_profile = instance_double(RubyProf::Profile)
      expect(RubyProf).to receive(:start)
      expect(RubyProf).to receive(:stop).and_return(rp_profile)
      test_value = false
      profiler.prof { test_value = true }
      expect(test_value).to be true
      expect(profiler.results).to eq rp_profile
    end
  end

  describe '#print_results_flat' do
    it 'returns the printer and prints to the path we pass in' do
      printer = instance_double(RubyProf::FlatPrinterWithLineNumbers)
      profiler.prof { 'we just want #prof to run' }
      expected_filepath = "log/profile_test#{Time.current.localtime.strftime('%FT%T')}-flat.txt"
      expect(RubyProf::FlatPrinterWithLineNumbers).to receive(:new).with(profiler.results).and_return(printer)
      expect(printer).to receive(:print) do |file|
        # this expectation might need to relax
        # if enough time lags between the timestamps
        # in expected_filepath and the file name itself
        expect(file.path).to eq expected_filepath
      end
      profiler.print_results_flat('test')
    end
  end
end
