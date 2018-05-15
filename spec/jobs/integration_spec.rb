require 'rails_helper'

describe 'the whole replication pipeline', type: :job do # rubocop:disable RSpec/DescribeClass
  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }
  let(:endpoint) { 's3' }
  let(:checksum) { '12345ABC' }
  let(:hash) do
    { druid: druid, version: version, endpoint: endpoint, checksum: checksum }
  end
  let(:object) { instance_double(Aws::S3::Object, exists?: false, put: true) }
  let(:bucket) { instance_double(Aws::S3::Bucket, object: object) }

  around do |example|
    old_adapter = ApplicationJob.queue_adapter
    ApplicationJob.queue_adapter = :inline
    example.run
    ApplicationJob.queue_adapter = old_adapter
  end

  before do
    allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
    allow(PreservationCatalog::S3).to receive(:bucket).and_return(bucket)
  end

  it 'gets from zipmaker queue to replication result message' do
    expect(PlexerJob).to receive(:perform_later).with(druid, version).and_call_original
    expect(S3EndpointDeliveryJob).to receive(:perform_later).with(druid, version).and_call_original
    # other enpoints as added...
    expect(ResultsRecorderJob).to receive(:perform_later).with(druid, version, endpoint, checksum).and_call_original
    expect(Resque.redis.redis).to receive(:lpush).with('replication.results', hash.to_json)
    ZipmakerJob.perform_now(druid, version)
  end
end
