require 'rails_helper'

describe ResultsRecorderJob, type: :job do
  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }
  let(:endpoint) { 's3' }
  let(:checksum) { '12345ABC' }

  it 'descends from ApplicationJob' do
    expect(described_class.new).to be_an(ApplicationJob)
  end

  it 'posts a message to replication.results queue' do
    hash = { druid: druid, version: version, endpoint: endpoint, checksum: checksum }
    expect(Resque.redis.redis).to receive(:lpush).with('replication.results', hash.to_json)
    described_class.perform_now(druid, version, endpoint, checksum)
  end
end
