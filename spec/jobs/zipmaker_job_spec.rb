require 'rails_helper'

describe ZipmakerJob, type: :job do
  let(:druid) { 'bj102hs9687' }
  let(:dvz_part) { instance_double(DruidVersionZipPart, metadata: { fake: 1 }) }
  let(:version) { 1 }
  let(:zip_path) { "spec/fixtures/zip_storage/bj/102/hs/9687/#{druid}#{format('.v%04d.zip', version)}" }
  let(:job) do
    described_class.new(druid, version).tap { |j| j.zip = DruidVersionZip.new(druid, version) }
  end

  before do
    allow(PlexerJob).to receive(:perform_later).with(any_args)
    allow(Settings).to receive(:zip_storage).and_return('spec/fixtures/zip_storage')
  end

  it 'descends from DruidVersionJobBase' do
    expect(described_class.new).to be_a(DruidVersionJobBase)
  end

  it 'invokes PlexerJob' do
    expect(PlexerJob).to receive(:perform_later).with(druid, version, 'bj/102/hs/9687/bj102hs9687.v0001.zip', Hash)
    described_class.perform_now(druid, version)
  end

  it 'handles segmented zips, invokes PlexerJob per part' do
    allow(DruidVersionZipPart).to receive(:new).and_return(dvz_part)
    allow(job.zip).to receive(:part_keys).and_return(
      [
        'bj/102/hs/9687/bj102hs9687.v0001.zip',
        'bj/102/hs/9687/bj102hs9687.v0001.z01',
        'bj/102/hs/9687/bj102hs9687.v0001.z02'
      ]
    )
    expect(PlexerJob).to receive(:perform_later).with(druid, version, 'bj/102/hs/9687/bj102hs9687.v0001.zip', Hash)
    expect(PlexerJob).to receive(:perform_later).with(druid, version, 'bj/102/hs/9687/bj102hs9687.v0001.z01', Hash)
    expect(PlexerJob).to receive(:perform_later).with(druid, version, 'bj/102/hs/9687/bj102hs9687.v0001.z02', Hash)
    job.perform(druid, version)
  end

  context 'zip already exists in zip storage' do
    it 'does not create a zip, but touches it' do
      expect(File).to exist(zip_path)
      expect(FileUtils).to receive(:touch).with(job.zip.file_path)
      expect(job.zip).not_to receive(:create_zip!)
      job.perform(druid, version)
    end
  end

  context 'zip is not yet in zip storage' do
    let(:version) { 3 }

    before { allow(DruidVersionZipPart).to receive(:new).and_return(dvz_part) }

    it 'creates the zip' do
      expect(File).not_to exist(zip_path)
      expect(job.zip).to receive(:create_zip!)
      job.perform(druid, version)
    end
  end
end
