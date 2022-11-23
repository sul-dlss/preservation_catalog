# frozen_string_literal: true

require 'rails_helper'
require 'services/audit/shared_examples_replication_to_endpoint'

RSpec.describe Audit::ReplicationToIbm do
  # Shared examples takes: klass, bucket_name, check_name, endpoint_name, region
  it_behaves_like 'replication to endpoint', Replication::IbmProvider, 'sul-sdr-us-west-bucket', 'IbmAuditSpec', 'ibm_us_south', 'us-south'
end
