module PreservationCatalog
  # The Application's configured interface to S3.
  module Ibm
    class << self
      delegate :client, to: :bucket

      # @return [Aws::S3::Bucket]
      def bucket
        resource.bucket(bucket_name)
      end

      # Because AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_REGION will be managed via
      # ENV vars, and the bucket must match those, we check for AWS_BUCKET_NAME first.
      # @return [String]
      def bucket_name
        ENV['AWS_BUCKET_NAME'] || Settings.ibm.bucket_name
      end

      # @return [Aws::S3::Resource]
      def resource
        Aws::S3::Resource.new(endpoint: Settings.zip_endpoints.ibm_us_south.endpoint_node)
      end
    end
  end
end
