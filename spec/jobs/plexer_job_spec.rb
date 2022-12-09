# frozen_string_literal: true

require 'rails_helper'

describe PlexerJob do
  let(:dvz) { Replication::DruidVersionZip.new(druid, version) }
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

  before do
    allow(Replication::DruidVersionZip).to receive(:new).with(druid, version).and_return(dvz)
  end

  it 'descends from ZipPartJobBase' do
    expect(described_class.new).to be_a(ZipPartJobBase)
  end

  describe '#perform_later' do
    let(:redis) { instance_double(Redis, setnx: true) }

    before do
      allow(Sidekiq).to receive(:redis).and_yield(redis)
    end

    it 'raises without enqueueing if size metadata is incomplete' do
      expect { described_class.perform_later(druid, version, 'part_key', metadata.merge(size: nil)) }
        .to raise_error(ArgumentError, /size/)
    end

    it 'raises without enqueueing if zip_cmd metadata is incomplete' do
      expect { described_class.perform_later(druid, version, 'part_key', metadata.reject { |x| x == :zip_cmd }) }
        .to raise_error(ArgumentError, /zip_cmd/)
    end
  end

  describe '#perform' do
    let(:parts1) { po.zipped_moab_versions.first!.zip_parts }
    let(:parts2) { po.zipped_moab_versions.second!.zip_parts }
    let(:parts3) { po.zipped_moab_versions.third!.zip_parts }
    let(:s3_key) { dvz.s3_key(metadata[:suffix]) }
    let(:metadata_non_matching) do
      {
        checksum_md5: '4f98f59e877ecb84ff75ef0fab45bac5',
        size: 145,
        parts_count: 3,
        suffix: '.zip',
        zip_cmd: 'zip -xyz ...',
        zip_version: 'Zip 3.0 (July 5th 2008)'
      }
    end

    before do
      create(:zip_endpoint, delivery_class: 2) # new 3rd endpoint, preserved_object should 3 ZMVs
      create(:moab_record, preserved_object: po, version: po.current_version)
    end

    it 'splits the message out to endpoints' do
      expect(S3WestDeliveryJob).to receive(:perform_later)
        .with(druid, version, s3_key, a_hash_including(:checksum_md5, :size, :zip_cmd, :zip_version))
      expect(S3EastDeliveryJob).to receive(:perform_later)
        .with(druid, version, s3_key, a_hash_including(:checksum_md5, :size, :zip_cmd, :zip_version))
      expect(IbmSouthDeliveryJob).to receive(:perform_later)
        .with(druid, version, s3_key, a_hash_including(:checksum_md5, :size, :zip_cmd, :zip_version))
      described_class.perform_now(druid, version, s3_key, metadata)
    end

    it 'ensures zip_part exists with status unreplicated before queueing for delivery' do
      # intercept the jobs that'd try to deliver and mark 'ok'
      allow(S3WestDeliveryJob).to receive(:perform_later)
      allow(S3EastDeliveryJob).to receive(:perform_later)
      allow(IbmSouthDeliveryJob).to receive(:perform_later)

      described_class.perform_now(druid, version, s3_key, metadata)
      expect(parts1.map(&:status)).to eq ['unreplicated']
      expect(parts2.map(&:status)).to eq ['unreplicated']
      expect(parts3.map(&:status)).to eq ['unreplicated']
    end

    it 'adds ZipPart to each related ZMV' do
      expect(po.zipped_moab_versions.count).to eq 3
      described_class.perform_now(druid, version, s3_key, metadata)
      expect(parts1.map(&:md5)).to eq [md5]
      expect(parts2.map(&:md5)).to eq [md5]
      expect(parts3.map(&:md5)).to eq [md5]
      expect(parts1.first!.create_info).to eq metadata.slice(:zip_cmd, :zip_version).to_s
    end

    context 'when one zip_part exists already' do
      it 'only creates the two missing zip_parts' do
        # create one zip_part
        po.zipped_moab_versions.first!.zip_parts.create!({ md5: md5,
                                                           size: 123,
                                                           parts_count: 3,
                                                           suffix: '.zip',
                                                           create_info: 'zip -xyz ...Zip 3.0 (July 5th 2008)' })
        described_class.perform_now(druid, version, s3_key, metadata_non_matching) # tries to create three zip_parts
        expect(parts1.map(&:md5)).to eq [md5]
        expect(parts2.map(&:md5)).to eq [metadata_non_matching[:checksum_md5]]
        expect(parts3.map(&:md5)).to eq [metadata_non_matching[:checksum_md5]]
      end
    end
  end
end
