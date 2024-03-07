# frozen_string_literal: true

require 'rails_helper'

RSpec.describe GisExporter do
  let(:moab) { Moab::StorageObject.new(druid, path) }
  let(:export_dir) { 'spec/temp/gis_export' }
  let(:gis) { described_class.new(druid, export_dir) }

  before do
    FileUtils.rm_r(export_dir) if File.directory?(export_dir)
    allow(Moab::StorageServices).to receive(:find_storage_object).with(druid).and_return(moab)
  end

  context 'when item has a data.zip' do
    let(:druid) { 'druid:tw464vg5223' }
    let(:path) { 'spec/fixtures/storage_root_gis/sdr2objects/tw/464/vg/5223/tw464vg5223' }

    describe '#druid' do
      it 'gets the druid' do
        expect(gis.druid).to eq('druid:tw464vg5223')
      end
    end

    describe '#has_data_zip?' do
      it 'can see if the item contains a data.zip' do
        expect(gis.data_zip?).to be(true)
      end
    end

    describe '#content_files' do
      it 'can find item content files' do
        filenames = gis.content_files.map { |path| path.basename.to_s }.sort
        expect(filenames).to eq(
          [
            'AirMonitoringStations.shp.xml',
            'preview.jpg'
          ]
        )
      end
    end

    describe '#data_zip_entries' do
      it 'can find files inside the data.zip, minus the iso XML files' do
        filenames = gis.data_zip_entries.map(&:name).sort
        expect(filenames).to eq(
          [
            'AirMonitoringStations.dbf',
            'AirMonitoringStations.prj',
            'AirMonitoringStations.shp',
            'AirMonitoringStations.shp.xml',
            'AirMonitoringStations.shx'
          ]
        )
      end
    end

    describe '#run_export' do
      it 'has the correct files and file sizes' do
        gis.run_export
        files = Pathname.new(export_dir).children.sort

        expect(files[0].basename.to_s).to eq('AirMonitoringStations.dbf')
        expect(files[0].size).to eq(41_776)

        expect(files[1].basename.to_s).to eq('AirMonitoringStations.prj')
        expect(files[1].size).to eq(468)

        expect(files[2].basename.to_s).to eq('AirMonitoringStations.shp')
        expect(files[2].size).to eq(8_332)

        expect(files[3].basename.to_s).to eq('AirMonitoringStations.shp.xml')
        expect(files[3].size).to eq(64_616)

        expect(files[4].basename.to_s).to eq('AirMonitoringStations.shx')
        expect(files[4].size).to eq(2_452)

        expect(files[5].basename.to_s).to eq('preview.jpg')
        expect(files[5].size).to eq(26_314)
      end
    end
  end

  context 'when item lacks a data.zip' do
    let(:druid) { 'druid:tw464vg5224' }
    let(:path) { 'spec/fixtures/storage_root01/sdr2objects/tw/464/vg/5224/tw464vg5224' }

    describe '#has_data_zip' do
      it 'can see the item lacks a data.zip' do
        expect(gis.data_zip?).to be(false)
      end
    end

    describe '#run_export' do
      it 'export raises an exception' do
        expect {
          gis.run_export
        }.to raise_error(GisExporter::MissingDataZip)
      end
    end
  end
end
