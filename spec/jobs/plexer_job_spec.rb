require 'rails_helper'

describe PlexerJob, type: :job do
  let(:job) { described_class.new(druid, version, metadata).tap { |j| j.zip = DruidVersionZip.new(druid, version) } }
  let(:druid) { 'bj102hs9687' }
  let(:endpoint) { create(:archive_endpoint_deprecated, delivery_class: 1) } # default
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

  it 'descends from DruidVersionJobBase' do
    expect(job).to be_an(DruidVersionJobBase)
  end

  it 'raises without enqueueing if metadata is incomplete' do
    expect { described_class.perform_later(druid, version, metadata.merge(size: nil)) }
      .to raise_error(ArgumentError, /size/)
    expect { described_class.perform_later(druid, version, metadata.reject { |x| x == :zip_cmd }) }
      .to raise_error(ArgumentError, /zip_cmd/)
  end

  describe '#perform' do
    let(:pc) { create(:preserved_copy, preserved_object: po) }
    let!(:apc) { create(:archive_preserved_copy, preserved_copy: pc, version: version) }
    let(:zc) { pc.zip_checksums.first }
    let(:s3_key) { job.zip.s3_key(metadata[:suffix]) }

    it 'splits the message out to endpoint(s)' do
      expect(S3WestDeliveryJob).to receive(:perform_later)
        .with(
          druid,
          version,
          s3_key,
          a_hash_including(:checksum_md5, :size, :zip_cmd, :zip_version)
        )
      job.perform(druid, version, s3_key, metadata)
    end

    it 'adds ArchivePreservedCopyPart rows' do
      allow(job).to receive(:targets).and_return([])
      job.perform(druid, version, s3_key, metadata)
      expect(pc).not_to be_nil
      expect(zc.archive_preserved_copy).to eq md5
      expect(zc.create_info).to eq metadata.slice(:zip_cmd, :zip_version).to_s
    end
  end
end
