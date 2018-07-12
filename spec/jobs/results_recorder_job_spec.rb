require 'rails_helper'

describe ResultsRecorderJob, type: :job do
  let(:apc) { create(:archive_preserved_copy) }
  let(:druid)    { apc.preserved_object.druid }
  let(:endpoint) { apc.archive_endpoint }

  before { apc.zip_parts.create(attributes_for(:zip_part)) }

  it 'descends from ApplicationJob' do
    expect(described_class.new).to be_an(ApplicationJob)
  end

  context 'when all parts for endpoint are replicated' do
    it 'sets the ArchivePreservedCopy status to ok' do
      described_class.perform_now(druid, apc.version, 'fake.zip', endpoint.delivery_class.to_s)
      expect(apc.reload).to be_ok
    end
    it 'sets part status to ok' do
      skip 'write test for individual part status'
    end
  end

  context 'when some parts for endpoint are replicated' do
    it 'does not set parent archive_preserved_copy status to ok' do
      skip 'write test for parent apc status'
    end
  end

  context 'when all endpoints are fulfilled' do
    it 'posts a message to replication.results queue' do
      hash = { druid: druid, version: apc.version, endpoints: [endpoint.endpoint_name] }
      expect(Resque.redis.redis).to receive(:lpush).with('replication.results', hash.to_json)
      described_class.perform_now(druid, apc.version, 'fake.zip', endpoint.delivery_class.to_s)
    end
  end

  context 'when other endpoints remain unreplicated' do
    let(:other_ep) { create(:archive_endpoint, delivery_class: 2) }

    before do
      create(:archive_preserved_copy, preserved_copy: apc.preserved_copy, archive_endpoint: other_ep)
    end

    it 'does not send to replication.results queue' do
      expect(Resque.redis.redis).not_to receive(:lpush)
      described_class.perform_now(druid, apc.version, 'fake.zip', endpoint.delivery_class.to_s)
    end
  end
end
