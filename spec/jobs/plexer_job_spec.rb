require 'rails_helper'

describe PlexerJob, type: :job do
  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }

  it 'descends from ApplicationJob' do
    expect(described_class.new).to be_an(ApplicationJob)
  end

  # future: does some replication logic
  it 'splits the message out to endpoint(s)' do
    expect(S3EndpointDeliveryJob).to receive(:perform_later).with(druid, version)
    described_class.perform_now(druid, version)
  end
end
