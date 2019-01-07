require 'rails_helper'

describe PlexerJob, type: :job do
  let(:job) { described_class.new(druid, version, metadata).tap { |j| j.zip = DruidVersionZip.new(druid, version) } }
  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }
  let(:md5) { 'd41d8cd98f00b204e9800998ecf8427e' }
  let(:metadata) do
    {
      checksum_md5: md5,
      size: 123,
      parts_count: 3,
      suffix: '.zip',
      zip_cmd: 'zip -xyz ...',
      zip_version: 'Zip 3.0 (July 5th 2008)'
    }
  end
  let(:po) { create(:preserved_object, druid: druid, current_version: version) }

  before { allow(S3WestDeliveryJob).to receive(:perform_later).with(any_args) }

  it 'descends from ZipPartJobBase' do
    expect(job).to be_an(ZipPartJobBase)
  end

  it 'raises without enqueueing if metadata is incomplete' do
    expect { described_class.perform_later(druid, version, 'part_key', metadata.merge(size: nil)) }
      .to raise_error(ArgumentError, /size/)
    expect { described_class.perform_later(druid, version, 'part_key', metadata.reject { |x| x == :zip_cmd }) }
      .to raise_error(ArgumentError, /zip_cmd/)
  end

  describe '#perform' do
    let!(:cm) do
      create(:zip_endpoint, delivery_class: 2) # 2nd endpoint ensures cm has 2 ZMVs
      create(:complete_moab, preserved_object: po)
    end
    let(:parts1) { cm.zipped_moab_versions.first!.zip_parts }
    let(:parts2) { cm.zipped_moab_versions.second!.zip_parts }
    let(:s3_key) { job.zip.s3_key(metadata[:suffix]) }

    it 'splits the message out to endpoints' do
      expect(S3WestDeliveryJob).to receive(:perform_later)
        .with(druid, version, s3_key, a_hash_including(:checksum_md5, :size, :zip_cmd, :zip_version))
      expect(S3EastDeliveryJob).to receive(:perform_later)
        .with(druid, version, s3_key, a_hash_including(:checksum_md5, :size, :zip_cmd, :zip_version))
      job.perform(druid, version, s3_key, metadata)
    end

    it 'ensures zip_part exists with status unreplicated before queueing for delivery' do
      skip('need test for ensuring part exists with status unreplicated')
    end

    it 'adds ZipPart to each related ZMV' do
      expect(cm.zipped_moab_versions.count).to eq 3
      job.perform(druid, version, s3_key, metadata)
      expect(parts1.map(&:md5)).to eq [md5]
      expect(parts2.map(&:md5)).to eq [md5]
      expect(parts1.first!.create_info).to eq metadata.slice(:zip_cmd, :zip_version).to_s
    end
  end
end
