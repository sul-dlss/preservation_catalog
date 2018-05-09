require 'rails_helper'

describe S3EndpointDeliveryJob, type: :job do
  let(:druid) { 'bj102hs9687' }
  let(:dvz) { DruidVersionZip.new(druid, version) }
  let(:version) { 1 }

  it 'descends from EndpointDeliveryBase' do
    expect(described_class.new).to be_an(EndpointDeliveryBase)
  end

  it 'populates a DruidVersionZip' do
    allow(dvz).to receive(:exists?).and_return(true)
    expect(DruidVersionZip).to receive(:new).with(druid, version).and_return(dvz)
    described_class.perform_now(druid, version)
  end

  it 'invokes ResultsRecorderJob' do
    expect(ResultsRecorderJob).to receive(:perform_later).with(druid, version, 's3', '12345ABC')
    described_class.perform_now(druid, version)
  end
end
