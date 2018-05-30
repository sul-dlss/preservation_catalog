describe S3EastDeliveryJob, type: :job do
  it 'descends from S3EndpointDeliveryJob' do
    expect(described_class.new).to be_an(S3EndpointDeliveryJob)
  end

  it 'uses a different queue' do
    expect(described_class.new.queue_name).to eq 's3_us_east_1_delivery'
  end
end
