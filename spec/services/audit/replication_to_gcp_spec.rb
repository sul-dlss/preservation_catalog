# frozen_string_literal: true

require 'rails_helper'
require 'services/audit/shared_examples_replication_to_endpoint'

RSpec.describe Audit::ReplicationToGcp do
  # Shared examples takes: klass, bucket_name, check_name, endpoint_name, region
  it_behaves_like 'replication to endpoint', Replication::GcpProvider, 'sul-sdr-gcp-bucket', 'GcpAuditSpec', 'gcp_s3_south_1', 'us-south1'
end
