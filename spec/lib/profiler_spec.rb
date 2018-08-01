require 'profiler'
require 'ruby-prof'

RSpec.describe Profiler do
  let(:profiler) { described_class.new }
  let(:faketime) { Time.at(628_232_400).utc } # 1989-11-27 21:00:00 -0800 == 1989-11-28 05:00:00 UTC

  describe '.print_profile' do
    before { allow(described_class).to receive(:new).and_return(profiler) }

    it 'starts, yields, stops, and returns instance' do
      expect(RubyProf).to receive(:start)
      expect(RubyProf).to receive(:stop).and_return(instance_double(RubyProf::Profile))
      test_value = false
      return_val = described_class.print_profile { test_value = true }
      expect(test_value).to be true
      expect(return_val).to eq profiler
    end

    it 'prints if given an out_file_id' do
      allow(profiler).to receive(:prof)
      expect(profiler).to receive(:print_results_flat).with('foobar')
      described_class.print_profile('foobar') { 'noop' }
    end

    it 'does not print without an out_file_id' do
      allow(profiler).to receive(:prof)
      expect(profiler).not_to receive(:print_results_flat)
      described_class.print_profile { 'noop' }
    end
  end

  describe '#output_path' do
    before { allow(Time).to receive(:now).and_return(faketime) }

    it 'returns the path of results file' do
      expect(profiler.output_path('test')).to eq "log/profile_test#{faketime.localtime.strftime('%FT%T')}-flat.txt"
    end
  end

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
    let(:path) { 'log/profile_test-flat.txt' }

    before { allow(profiler).to receive(:output_path).and_return(path) }

    after { FileUtils.rm_f(path) } # cleanup

    it 'returns the printer and prints to the path we pass in' do
      printer = instance_double(RubyProf::FlatPrinterWithLineNumbers, print: nil)
      profiler.prof { 'we just want #prof to run' }
      expect(RubyProf::FlatPrinterWithLineNumbers).to receive(:new).with(profiler.results).and_return(printer)
      profiler.print_results_flat('test')
    end
  end
end
