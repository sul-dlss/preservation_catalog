require 'rails_helper'

describe PlexerJob, type: :job do
  let(:job) { described_class.new }
  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }
  let(:md5) { '1B2M2Y8AsgTpgAmY7PhCfg==' }
  let(:metadata) do
    {
      checksum_md5: md5,
      size: 123,
      zip_cmd: 'zip -xyz ...',
      zip_version: 'Zip 3.0 (July 5th 2008)'
    }
  end

  it 'descends from ApplicationJob' do
    expect(job).to be_an(ApplicationJob)
  end

  describe '#perform' do
    before { allow(job).to receive(:targets).and_return([S3EndpointDeliveryJob]) }

    it 'splits the message out to endpoint(s)' do
      expect(S3EndpointDeliveryJob).to receive(:perform_later)
        .with(
          druid,
          version,
          a_hash_including(:checksum_md5, :size, :zip_cmd, :zip_version)
        )
      job.perform(druid, version, metadata)
    end
  end

  describe '#targets' do
    let(:po) { create(:preserved_object, druid: druid) }

    before { create(:preserved_copy, preserved_object: po, version: version, endpoint: endpoint) }

    context 'with undeliverable PC Endpoints' do
      let(:endpoint) { create(:archive_endpoint, delivery_class: nil) }

      it 'logs but does not raise' do
        expect(Rails.logger).to receive(:error).with(/no delivery_class/)
        expect(job.targets(druid, version)).to eq []
      end
    end

    context 'with deliverable PC Endpoints' do
      let(:endpoint) { create(:archive_endpoint, delivery_class: 1) }

      it 'returns classes' do
        expect(Rails.logger).not_to receive(:error)
        expect(job.targets(druid, version)).to eq [S3EndpointDeliveryJob]
      end
    end
  end
end
