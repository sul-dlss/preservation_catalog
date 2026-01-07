# frozen_string_literal: true

module Replication
  # Factory for an S3 Bucket object for the AWS S3 West endpoint.
  class S3WestBucketFactory
    # @return [Aws::S3::Bucket]
    def self.bucket
      Replication::AwsProvider.new(
        region: Settings.zip_endpoints.aws_s3_west_2.region,
        access_key_id: Settings.zip_endpoints.aws_s3_west_2.access_key_id,
        secret_access_key: Settings.zip_endpoints.aws_s3_west_2.secret_access_key
      ).bucket
    end
  end
end
