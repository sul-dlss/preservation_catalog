# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reporter do
  let!(:test_start_time) { DateTime.now } # useful for both output cleanup and CSV filename testing

  let!(:msr_a) { create(:moab_storage_root) }
  let!(:complete_moab_1) { create(:complete_moab, moab_storage_root: msr_a) }
  let!(:complete_moab_2) { create(:complete_moab, moab_storage_root: msr_a) }
  let!(:complete_moab_3) { create(:complete_moab, moab_storage_root: msr_a) }

  let!(:msr_b) { create(:moab_storage_root) }
  let!(:complete_moab_4) { create(:complete_moab, moab_storage_root: msr_b) }
  let!(:complete_moab_5) { create(:complete_moab, moab_storage_root: msr_b) }
  let!(:complete_moab_6) { create(:complete_moab, moab_storage_root: msr_b) }

  after do
    next unless FileTest.exist?(described_class.default_filepath)
    Dir.each_child(described_class.default_filepath) do |filename|
      fullpath_filename = File.join(described_class.default_filepath, filename)
      File.unlink(fullpath_filename) if File.stat(fullpath_filename).mtime > test_start_time
    end
  end

  describe '.moab_storage_root_druid_list_to_csv' do
    it 'creates a file containing a list of druids from the given storage root' do
      csv_filename = described_class.moab_storage_root_druid_list_to_csv(storage_root_name: msr_b.name)
      expect(CSV.read(csv_filename)).to eq(
        [complete_moab_4, complete_moab_5, complete_moab_6].map { |cm| [cm.preserved_object.druid] }
      )
    end

    it 'names the file with the default prefix and a timestamp and writes it to the default location' do
      # file timestamp is to the second, but test_start_time is more precise.  this sleep allows us to compare
      # timestamp to test start time without having to round fractions of a second.
      sleep(1.second)

      csv_filename = described_class.moab_storage_root_druid_list_to_csv(storage_root_name: msr_a.name)
      expect(csv_filename).to match(%r{^#{described_class.default_filepath}\/MoabStorageRoot_#{msr_a.name}_druids_.*\.csv$})
      timestamp_str = /MoabStorageRoot_#{msr_a.name}_druids_(.*)\.csv$/.match(csv_filename).captures[0]
      expect(DateTime.parse(timestamp_str)).to be >= test_start_time
    end

    it 'allows the caller to specify an alternate filename, including full path' do
      alternate_filename = '/tmp/my_cool_druid_export.csv'
      csv_filename = described_class.moab_storage_root_druid_list_to_csv(storage_root_name: msr_a.name, csv_filename: alternate_filename)
      expect(csv_filename).to eq(alternate_filename)
      expect(CSV.read(csv_filename)).to eq(
        [complete_moab_1, complete_moab_2, complete_moab_3].map { |cm| [cm.preserved_object.druid] }
      )
    ensure
      File.unlink(alternate_filename) if FileTest.exist?(alternate_filename)
    end

    it 'lets the DB error bubble up if the given storage root does not exist' do
      expect { described_class.moab_storage_root_druid_list_to_csv(storage_root_name: 'nonexistent') }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises an error if the intended file name is already in use' do
      duplicated_filename = File.join(described_class.default_filepath, 'my_duplicated_filename.csv')
      described_class.moab_storage_root_druid_list_to_csv(storage_root_name: msr_b.name, csv_filename: duplicated_filename)
      expect {
        described_class.moab_storage_root_druid_list_to_csv(storage_root_name: msr_b.name, csv_filename: duplicated_filename)
      }.to raise_error(StandardError, "#{duplicated_filename} already exists, aborting!")
    end
  end
end
