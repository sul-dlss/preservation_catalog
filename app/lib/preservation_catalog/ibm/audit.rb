# frozen_string_literal: true

module PreservationCatalog
  module Ibm
    # Methods for auditing the state of a ZippedMoabVersion on an IBM S3 compatible endpoint.
    class Audit < PreservationCatalog::S3Audit
      def s3_provider_class
        ::PreservationCatalog::IbmProvider
      end
    end
  end
end
