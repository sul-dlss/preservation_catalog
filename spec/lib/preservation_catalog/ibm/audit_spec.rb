# frozen_string_literal: true

require 'rails_helper'
require 'lib/preservation_catalog/shared_examples_s3_audit'

RSpec.describe PreservationCatalog::Ibm::Audit do
  # Shared examples takes: klass, bucket_name, check_name, endpoint_name, region
  it_behaves_like 's3 audit', PreservationCatalog::Ibm, 'sul-sdr-us-west-bucket', 'IbmAuditSpec', 'ibm_us_south', 'us-south'
end
