# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Replication::GcpBucketFactory do
  subject(:bucket) { described_class.bucket }

  it 'returns a bucket' do
    expect(bucket).to be_a(Aws::S3::Bucket)
    expect(bucket.name).to eq(Settings.zip_endpoints.gcp_s3_south_1.storage_location)
  end
end
