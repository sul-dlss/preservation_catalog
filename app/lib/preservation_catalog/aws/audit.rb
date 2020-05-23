# frozen_string_literal: true

module PreservationCatalog
  module Aws
    # Methods for auditing the state of a ZippedMoabVersion on an AWS S3 endpoint.
    class Audit < PreservationCatalog::S3Audit
      delegate :bucket_name, to: ::PreservationCatalog::Aws

      private

      def bucket
        endpoint = zmv.zip_endpoint.endpoint_name
        ::PreservationCatalog::Aws.configure(region: Settings.zip_endpoints[endpoint].region,
                                             access_key_id: Settings.zip_endpoints[endpoint].access_key_id,
                                             secret_access_key: Settings.zip_endpoints[endpoint].secret_access_key)
        ::PreservationCatalog::Aws.bucket
      end
    end
  end
end
