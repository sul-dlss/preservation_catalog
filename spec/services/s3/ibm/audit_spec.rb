# frozen_string_literal: true

require 'rails_helper'
require 'services/s3/shared_examples_s3_audit'

RSpec.describe S3::Ibm::Audit do
  # Shared examples takes: klass, bucket_name, check_name, endpoint_name, region
  it_behaves_like 's3 audit', S3::IbmProvider, 'sul-sdr-us-west-bucket', 'IbmAuditSpec', 'ibm_us_south', 'us-south'
end
