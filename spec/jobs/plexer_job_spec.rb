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
    let(:east_ep) { create(:archive_endpoint, delivery_class: 2) }
    let(:pc) { create(:preserved_copy, preserved_object: po) }
    let!(:apc1) { create(:archive_preserved_copy, preserved_copy: pc, version: version) }
    let!(:apc2) { create(:archive_preserved_copy, preserved_copy: pc, version: version, archive_endpoint: east_ep) }
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

    it 'adds ZipPart to each related APC' do
      job.perform(druid, version, s3_key, metadata)
      apc1.zip_parts.reload
      apc2.zip_parts.reload
      expect(apc1.zip_parts.count).to eq 1
      expect(apc2.zip_parts.count).to eq 1
      expect(apc1.zip_parts.first!.md5).to eq md5
      expect(apc2.zip_parts.first!.md5).to eq md5
      expect(apc1.zip_parts.first!.create_info).to eq metadata.slice(:zip_cmd, :zip_version).to_s
    end
  end
end
