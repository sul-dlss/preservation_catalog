# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoabStorageRootReportService do
  let!(:test_start_time) { DateTime.now.utc.iso8601 } # useful for both output cleanup and CSV filename testing

  let!(:msr_a) { create(:moab_storage_root) }
  let!(:complete_moab_1) { create(:complete_moab, moab_storage_root: msr_a) }
  let!(:complete_moab_2) { create(:complete_moab, moab_storage_root: msr_a) }
  let!(:complete_moab_3) { create(:complete_moab, moab_storage_root: msr_a) }

  let(:reporter) { described_class.new(storage_root_name: msr_a.name) }

  describe '#druid_csv_list' do
    let(:druid_csv_list) {
      [['druid'],
       [complete_moab_1.preserved_object.druid],
       [complete_moab_2.preserved_object.druid],
       [complete_moab_3.preserved_object.druid]]
    }

    it 'returns a list of druids on a storage_root' do
      expect(reporter.druid_csv_list).to eq(druid_csv_list)
    end
  end

  describe '#moab_detail_csv_list' do
    let(:moab_detail_csv_list) do
      header_row = [
        ['druid', 'previous storage root', 'current storage root', 'last checksum validation', 'last moab validation', 'status', 'status details']
      ]
      data_rows = [complete_moab_1, complete_moab_2, complete_moab_3].map do |cm|
        [cm.preserved_object.druid, nil, cm.moab_storage_root.name, nil, nil, 'ok', nil]
      end
      header_row + data_rows
    end

    it 'returns a hash of values for the given moab' do
      expect(reporter.moab_detail_csv_list).to eq(moab_detail_csv_list)
    end
  end

  describe '#write_to_csv' do
    let(:csv_lines) do
      [
        ['header1', 'header2', 'header3', 'header4', 'headers', 'are_really_just_like', 'other rows'],
        ['test_val1', 'test_val2', nil, nil, 'ok', nil, 'another value']
      ]
    end

    let(:default_filepath) { Rails.root.join('log', 'reports') }

    after do
      next unless FileTest.exist?(default_filepath)
      Dir.each_child(default_filepath) do |filename|
        fullpath_filename = File.join(default_filepath, filename)
        File.unlink(fullpath_filename) if File.stat(fullpath_filename).mtime > test_start_time
      end
    end

    it 'creates a default file containing the lines given to it' do
      csv_filename = reporter.write_to_csv(csv_lines, report_type: 'test')
      expect(CSV.read(csv_filename)).to eq(csv_lines)
      expect(csv_filename).to match(%r{^#{default_filepath}/storage_#{msr_a.name}_test_.*\.csv$})
      timestamp_str = /storage_#{msr_a.name}_test_(.*)\.csv$/.match(csv_filename).captures[0]
      # yes this lexically compares date strings, sorry. but they're very regular (always
      # the same length), and dropped colons makes DateTime parsing painful.
      expect(timestamp_str).to be >= test_start_time.to_s.gsub(':', '')
    end

    it 'allows the caller to specify a tag string, to more easily differentiate report runs' do
      report_tag = 'after_cv'
      csv_filename = reporter.write_to_csv(csv_lines, report_type: 'test', report_tag: report_tag)
      expect(csv_filename).to match(%r{^#{default_filepath}/storage_#{msr_a.name}_test_after_cv.*\.csv$})
      expect(CSV.read(csv_filename)).to eq(csv_lines)
    end

    it 'allows the caller to specify an alternate filename, including full path' do
      alternate_filename = '/tmp/my_cool_druid_export.csv'
      csv_filename = reporter.write_to_csv(csv_lines, filename: alternate_filename)
      expect(csv_filename).to eq(alternate_filename)
      expect(CSV.read(csv_filename)).to eq(csv_lines)
    ensure
      File.unlink(alternate_filename)
    end

    it 'raises an error if the intended file name is already in use' do
      duplicated_filename = File.join(default_filepath, 'my_duplicated_filename.csv')
      reporter.write_to_csv(csv_lines, filename: duplicated_filename)
      expect {
        reporter.write_to_csv(csv_lines, filename: duplicated_filename)
      }.to raise_error(StandardError, "#{duplicated_filename} already exists, aborting!")
    end

    it 'raises an ArgumentError if caller provides neither report_type nor filename' do
      expect { reporter.write_to_csv(csv_lines) }.to raise_error(ArgumentError, 'Must specify at least one of report_type or filename')
    end
  end
end
