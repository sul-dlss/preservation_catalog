# frozen_string_literal: true

module PreservationCatalog
  # The Application's configured interface to IBM's S3 compatible service.
  module Ibm
    class << self
      delegate :client, to: :resource
      attr_reader :aws_client_args

      def configure(region:, access_key_id:, secret_access_key:)
        @aws_client_args = {
          region: region,
          access_key_id: access_key_id,
          secret_access_key: secret_access_key,
          endpoint: Settings.zip_endpoints.ibm_us_south.endpoint_node
        }
      end

      # @return [Aws::S3::Bucket]
      def bucket
        resource.bucket(bucket_name)
      end

      # @return [String]
      def bucket_name
        ENV['AWS_BUCKET_NAME'] || Settings.zip_endpoints.ibm_us_south.storage_location || Settings.ibm.bucket_name
      end

      # @return [Aws::S3::Resource]
      def resource
        Aws::S3::Resource.new(aws_client_args)
      end
    end
  end
end
