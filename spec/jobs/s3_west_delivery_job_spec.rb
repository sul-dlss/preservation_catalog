require 'rails_helper'

describe S3WestDeliveryJob, type: :job do
  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }
  let(:dvz) { DruidVersionZip.new(druid, version) }
  let(:object) { instance_double(Aws::S3::Object, exists?: false, put: true) }
  let(:bucket) { instance_double(Aws::S3::Bucket, object: object) }
  let(:md5) { '4f98f59e877ecb84ff75ef0fab45bac5' }
  let(:metadata) { dvz.metadata.merge(zip_version: 'Zip 3.0 (July 5th 2008)') }

  before do
    allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
    allow(PreservationCatalog::S3).to receive(:bucket).and_return(bucket)
    allow(ResultsRecorderJob).to receive(:perform_later).with(any_args)
  end

  it 'descends from DruidVersionJobBase' do
    expect(described_class.new).to be_an(DruidVersionJobBase)
  end

  it 'populates a DruidVersionZip' do
    expect(DruidVersionZip).to receive(:new).with(druid, version).and_return(dvz)
    described_class.perform_now(druid, version, metadata)
  end

  context 'zip already exists on s3' do
    before { allow(object).to receive(:exists?).and_return(true) }

    it 'does nothing' do
      expect(object).not_to receive(:put)
      described_class.perform_now(druid, version, metadata)
    end
  end

  context 'zip is new to S3' do
    it 'puts to S3' do
      expect(object).to receive(:put).with(
        a_hash_including(body: File, content_md5: dvz.hex_to_base64(md5), metadata: a_hash_including(checksum_md5: md5))
      )
      described_class.perform_now(druid, version, metadata)
    end
  end

  it 'invokes ResultsRecorderJob' do
    expect(ResultsRecorderJob).to receive(:perform_later).with(druid, version, described_class.to_s)
    described_class.perform_now(druid, version, metadata)
  end
end
