module PreservationCatalog
  # The Application's configured interface to S3.
  module S3
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
        ENV['AWS_BUCKET_NAME'] || Settings.aws.bucket_name
      end

      # @return [Aws::S3::Resource]
      def resource
        if ENV['AWS_ENDPOINT']
          # Non-Amazon S3 use endpoints to override Amazon's REGION endpoint logic.
          Aws::S3::Resource.new(endpoint: ENV['AWS_ENDPOINT'])
        else
          # If AWS_ENDPOINT is not set we're using actual Amazon S3.
          Aws::S3::Resource.new
        end
      end
    end
  end
end
