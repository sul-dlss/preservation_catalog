# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Replication::S3EastBucketFactory do
  subject(:bucket) { described_class.bucket }

  let!(:aws_east_options) do
    Config::Options.new(
      region: 'us-east-1',
      endpoint_node: 'us-east-1',
      storage_location: 'sul-sdr-aws-us-east-1-test',
      access_key_id: 'overridden-by-env-var-in-ci',
      secret_access_key: 'overridden-by-env-var-in-ci',
      bucket_factory_class: 'Replication::S3EastBucketFactory'
    )
  end

  before do
    # aws_s3_east_1 isn't in test.yml.
    zip_endpoints_options = double(Config::Options) # rubocop:disable RSpec/VerifiedDoubles
    allow(zip_endpoints_options).to receive(:aws_s3_east_1).and_return(aws_east_options) # rubocop:disable RSpec/VariableNumber
    allow(zip_endpoints_options).to receive(:[]).with('aws_s3_east_1').and_return(aws_east_options)
    allow(Settings).to receive(:zip_endpoints).and_return(zip_endpoints_options)
  end

  it 'returns a bucket' do
    expect(bucket).to be_a(Aws::S3::Bucket)
    expect(bucket.name).to eq(aws_east_options.storage_location)
  end
end
