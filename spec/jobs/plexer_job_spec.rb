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
    let!(:pc) { create(:archive_copy_deprecated, preserved_object: po, version: version) }
    let(:zc) { pc.zip_checksums.first }

    it 'splits the message out to endpoint(s)' do
      allow(job).to receive(:targets).and_return([S3WestDeliveryJob])
      expect(S3WestDeliveryJob).to receive(:perform_later)
        .with(
          druid,
          version,
          a_hash_including(:checksum_md5, :size, :zip_cmd, :zip_version)
        )
      job.perform(druid, version, metadata)
    end

    it 'adds zip_checksum rows' do
      allow(job).to receive(:targets).and_return([])
      job.perform(druid, version, metadata)
      expect(pc).not_to be_nil
      expect(zc.md5).to eq md5
      expect(zc.create_info).to eq metadata.slice(:zip_cmd, :zip_version).to_s
    end

    it 'updates PreservedCopy#size' do
      job.perform(druid, version, metadata)
      expect(pc.reload.size).to eq metadata[:size]
    end
  end

  describe '#targets' do
    let(:endpoint_ids) { po.preserved_copies.pluck(:endpoint_id) }

    before { create(:preserved_copy, preserved_object: po, version: version, endpoint: endpoint) }

    it 'returns classes' do
      expect(Rails.logger).not_to receive(:error)
      expect(job.targets(endpoint_ids)).to eq [S3WestDeliveryJob]
    end

    context 'with undeliverable PC Endpoint(s)' do
      let(:endpoint) { create(:archive_endpoint_deprecated, delivery_class: nil) }

      it 'logs but does not raise' do
        expect(Rails.logger).to receive(:error).with(/no delivery_class/)
        expect(job.targets(endpoint_ids)).to eq []
      end
    end

    context 'with non-PC Endpoint(s)' do
      let(:endpoint) { create(:endpoint) }

      it 'returns empty Array' do
        expect(Rails.logger).to receive(:error).with(/no delivery_class/)
        expect(job.targets(endpoint_ids)).to eq []
      end
    end
  end
end
