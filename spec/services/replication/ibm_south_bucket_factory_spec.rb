# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Replication::IbmSouthBucketFactory do
  subject(:bucket) { described_class.bucket }

  it 'returns a bucket' do
    expect(bucket).to be_a(Aws::S3::Bucket)
    expect(bucket.name).to eq(Settings.zip_endpoints.ibm_us_south.storage_location)
  end
end
