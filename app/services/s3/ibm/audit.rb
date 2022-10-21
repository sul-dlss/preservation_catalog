# frozen_string_literal: true

module S3
  module Ibm
    # Methods for auditing the state of a ZippedMoabVersion on an IBM S3 compatible endpoint.
    class Audit < S3::S3Audit
      def s3_provider_class
        ::S3::IbmProvider
      end
    end
  end
end
