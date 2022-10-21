# frozen_string_literal: true

module S3
  module Aws
    # Methods for auditing the state of a ZippedMoabVersion on an AWS S3 endpoint.
    class Audit < S3::S3Audit
      def s3_provider_class
        ::S3::AwsProvider
      end
    end
  end
end
