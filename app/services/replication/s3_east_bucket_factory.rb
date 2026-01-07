# frozen_string_literal: true

module Replication
  # Factory for an S3 Bucket object for the AWS S3 East endpoint.
  class S3EastBucketFactory
    # @return [Aws::S3::Bucket]
    def self.bucket
      Replication::AwsProvider.new(
        region: Settings.zip_endpoints.aws_s3_east_1.region,
        access_key_id: Settings.zip_endpoints.aws_s3_east_1.access_key_id,
        secret_access_key: Settings.zip_endpoints.aws_s3_east_1.secret_access_key
      ).bucket
    end
  end
end
