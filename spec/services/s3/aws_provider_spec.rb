# frozen_string_literal: true

require 'rails_helper'
require 'services/s3/shared_examples_provider'

describe S3::AwsProvider do
  it_behaves_like 'provider', described_class,
                  Settings.zip_endpoints.aws_s3_west_2.storage_location,
                  Settings.zip_endpoints.aws_s3_west_2.region,
                  Settings.zip_endpoints.aws_s3_west_2.access_key_id,
                  Settings.zip_endpoints.aws_s3_west_2.secret_access_key
end
