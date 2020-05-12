# frozen_string_literal: true

module PreservationCatalog
  module AWS
    # Methods for auditing the state of a ZippedMoabVersion on an AWS S3 endpoint.
    class Audit  < PreservationCatalog::S3Audit
      delegate :bucket_name, to: ::PreservationCatalog::S3

      private

      def bucket
        endpoint = zmv.zip_endpoint.endpoint_name
        ::PreservationCatalog::S3.configure(region: Settings.zip_endpoints[endpoint].region,
                                            access_key_id: Settings.zip_endpoints[endpoint].access_key_id,
                                            secret_access_key: Settings.zip_endpoints[endpoint].secret_access_key)
        ::PreservationCatalog::S3.bucket
      end
    end
  end
end
