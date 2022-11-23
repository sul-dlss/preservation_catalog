# frozen_string_literal: true

require 'rails_helper'
require 'services/audit/shared_examples_replication_to_endpoint'

RSpec.describe Audit::ReplicationToAws do
  # Shared examples takes: klass, bucket_name, check_name, endpoint_name, region
  it_behaves_like 'replication to endpoint', Replication::AwsProvider, 'sul-sdr-us-west-bucket', 'S3AuditSpec', 'aws_s3_west_2', 'us-west-2'
end
