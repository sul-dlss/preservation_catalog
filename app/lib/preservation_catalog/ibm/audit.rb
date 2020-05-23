# frozen_string_literal: true

module PreservationCatalog
  module Ibm
    # Methods for auditing the state of a ZippedMoabVersion on an IBM S3 compatible endpoint.
    class Audit < PreservationCatalog::S3Audit
      delegate :bucket_name, to: ::PreservationCatalog::Ibm

      private

      def bucket
        endpoint = zmv.zip_endpoint.endpoint_name
        ::PreservationCatalog::Ibm.configure(
          region: Settings.zip_endpoints[endpoint].region,
          access_key_id: Settings.zip_endpoints[endpoint].access_key_id,
          secret_access_key: Settings.zip_endpoints[endpoint].secret_access_key
        )
        ::PreservationCatalog::Ibm.bucket
      end
    end
  end
end
