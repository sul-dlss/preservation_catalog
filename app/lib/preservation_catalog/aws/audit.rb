# frozen_string_literal: true

module PreservationCatalog
  module Aws
    # Methods for auditing the state of a ZippedMoabVersion on an AWS S3 endpoint.
    class Audit < PreservationCatalog::S3Audit
      def s3_provider_class
        ::PreservationCatalog::AwsProvider
      end
    end
  end
end
