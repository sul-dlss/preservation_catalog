# frozen_string_literal: true

module PreservationCatalog
  # The Application's configured interface to AWS S3.
  module S3
    class << self
      delegate :client, to: :resource
      attr_reader :aws_client_args

      def configure(region:, access_key_id:, secret_access_key:)
        @aws_client_args = {
          region: region,
          access_key_id: access_key_id,
          secret_access_key: secret_access_key
        }
      end

      # @return [Aws::S3::Bucket]
      def bucket
        resource.bucket(bucket_name)
      end

      # Because AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_REGION will be managed via
      # ENV vars, and the bucket must match those, we check for AWS_BUCKET_NAME first.
      # @return [String]
      def bucket_name
        ENV['AWS_BUCKET_NAME'] || Settings.aws.bucket_name
      end

      # @return [Aws::S3::Resource]
      def resource
        Aws::S3::Resource.new(aws_client_args)
      end
    end
  end
end
