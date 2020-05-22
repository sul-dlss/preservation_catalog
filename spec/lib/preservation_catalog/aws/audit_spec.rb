# frozen_string_literal: true

require 'rails_helper'
require 'lib/preservation_catalog/shared_examples_s3_audit'

RSpec.describe PreservationCatalog::AWS::Audit do
  # Shared examples takes: klass, bucket_name, check_name, endpoint_name, region
  it_behaves_like 's3 audit', PreservationCatalog::S3, "sul-sdr-us-west-bucket", "S3AuditSpec", 'aws_s3_west_2', 'us-west-2'
end
