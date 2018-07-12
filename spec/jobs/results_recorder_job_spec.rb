require 'rails_helper'

describe ResultsRecorderJob, type: :job do
  let(:apc) { create(:archive_preserved_copy) }
  let(:druid)    { apc.preserved_object.druid }
  let(:zip_endpoint) { apc.zip_endpoint }

  before { apc.archive_preserved_copy_parts.create(attributes_for(:archive_preserved_copy_part)) }

  it 'descends from ApplicationJob' do
    expect(described_class.new).to be_an(ApplicationJob)
  end

  context 'when all parts for zip_endpoint are replicated' do
    it 'sets the ArchivePreservedCopy status to ok' do
      described_class.perform_now(druid, apc.version, 'fake.zip', zip_endpoint.delivery_class.to_s)
      expect(apc.reload).to be_ok
    end
    it 'sets part status to ok' do
      skip 'write test for individual part status'
    end
  end

  context 'when some parts for zip_endpoint are replicated' do
    it 'does not set parent archive_preserved_copy status to ok' do
      skip 'write test for parent apc status'
    end
  end

  context 'when all zip_endpoints are fulfilled' do
    it 'posts a message to replication.results queue' do
      hash = { druid: druid, version: apc.version, zip_endpoints: [zip_endpoint.endpoint_name] }
      expect(Resque.redis.redis).to receive(:lpush).with('replication.results', hash.to_json)
      described_class.perform_now(druid, apc.version, 'fake.zip', zip_endpoint.delivery_class.to_s)
    end
  end

  context 'when other endpoints remain unreplicated' do
    let(:other_ep) { create(:zip_endpoint, delivery_class: 2) }

    before do
      create(:archive_preserved_copy, preserved_copy: apc.preserved_copy, zip_endpoint: other_ep)
    end

    it 'does not send to replication.results queue' do
      expect(Resque.redis.redis).not_to receive(:lpush)
      described_class.perform_now(druid, apc.version, 'fake.zip', zip_endpoint.delivery_class.to_s)
    end
  end
end
