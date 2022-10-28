# frozen_string_literal: true

module S3
  module Aws
    # Methods for auditing the state of a ZippedMoabVersion on an AWS S3 endpoint.
    # @note this class name appears in the configuration for the endpoints for which it audits content.
    #   Please update the configs for the various environments if it's renamed or moved.
    class Audit < S3::S3Audit
      def s3_provider_class
        ::S3::AwsProvider
      end
    end
  end
end
