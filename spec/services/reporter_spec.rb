# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reporter do
  let!(:test_start_time) { DateTime.now.utc.iso8601 } # useful for both output cleanup and CSV filename testing

  let!(:msr_a) { create(:moab_storage_root) }
  let!(:complete_moab_1) { create(:complete_moab, moab_storage_root: msr_a) }
  let!(:complete_moab_2) { create(:complete_moab, moab_storage_root: msr_a) }
  let!(:complete_moab_3) { create(:complete_moab, moab_storage_root: msr_a) }

  let(:reporter) { described_class.new(storage_root_name: msr_a.name) }

  describe '.druids' do
    let(:druid_list) {
      [complete_moab_1.preserved_object.druid,
       complete_moab_2.preserved_object.druid,
       complete_moab_3.preserved_object.druid]
    }

    it 'returns a list of druids on a storage_root' do
      expect(reporter.druids).to eq(druid_list)
    end
  end

  describe '.moab_detail_for' do
    let(:pos) { [complete_moab_1.preserved_object.druid] }
    let(:moab_detail) {
      [{ druid: complete_moab_1.preserved_object.druid,
         from_storage_root: nil,
         last_checksum_validation: nil,
         last_moab_validation: nil,
         status: 'ok',
         status_details: nil,
         storage_root: complete_moab_1.moab_storage_root.name }]
    }

    before do
      allow(PreservedObject).to receive(:find_by!).with(druid: pos.first)
    end

    it 'returns a hash of values for the given moab' do
      expect(reporter.moab_detail_for(pos)).to eq(moab_detail)
    end
  end

  describe '.write_to_csv' do
    let(:moab_detail) {
      [{ druid: 'bj102hs9687',
         from_storage_root: nil,
         last_checksum_validation: nil,
         last_moab_validation: nil,
         status: 'ok',
         status_details: nil,
         storage_root: 'moab_storage_root01' }]
    }

    after do
      next unless FileTest.exist?(reporter.default_filepath)
      Dir.each_child(reporter.default_filepath) do |filename|
        fullpath_filename = File.join(reporter.default_filepath, filename)
        File.unlink(fullpath_filename) if File.stat(fullpath_filename).mtime > test_start_time
      end
    end

    it 'creates a default file containing a list of druids from the given storage root' do
      csv_filename = reporter.write_to_csv(moab_detail)
      expect(CSV.read(csv_filename)).to eq([["bj102hs9687", nil, nil, nil, "ok", nil, "moab_storage_root01"]])
      expect(csv_filename).to match(%r{^#{reporter.default_filepath}\/MoabStorageRoot_#{msr_a.name}_druids_.*\.csv$})
      timestamp_str = /MoabStorageRoot_#{msr_a.name}_druids_(.*)\.csv$/.match(csv_filename).captures[0]
      expect(DateTime.parse(timestamp_str)).to be >= test_start_time
    end

    it 'allows the caller to specify an alternate filename, including full path' do
      alternate_filename = '/tmp/my_cool_druid_export.csv'
      csv_filename = reporter.write_to_csv(moab_detail, filename: alternate_filename)
      expect(csv_filename).to eq(alternate_filename)
      expect(CSV.read(csv_filename)).to eq([["bj102hs9687", nil, nil, nil, "ok", nil, "moab_storage_root01"]])
    ensure
      File.unlink(alternate_filename) if FileTest.exist?(alternate_filename)
    end

    it 'lets the DB error bubble up if the given storage root does not exist' do
      expect { described_class.new(storage_root_name: 'nonexistent') }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'raises an error if the intended file name is already in use' do
      duplicated_filename = File.join(reporter.default_filepath, 'my_duplicated_filename.csv')
      reporter.write_to_csv(moab_detail, filename: duplicated_filename)
      expect {
        reporter.write_to_csv(moab_detail, filename: duplicated_filename)
      }.to raise_error(StandardError, "#{duplicated_filename} already exists, aborting!")
    end
  end
end
