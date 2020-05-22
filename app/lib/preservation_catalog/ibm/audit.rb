# frozen_string_literal: true

module PreservationCatalog
  module Ibm
    # Methods for auditing the state of a ZippedMoabVersion on an IBM S3 compatible endpoint.
    class Audit < PreservationCatalog::S3Audit
      delegate :bucket_name, to: ::PreservationCatalog::Ibm

      def check_ibm_replicated_zipped_moab_version
        zmv.zip_parts.where.not(status: :unreplicated).each do |part|
          ibm_s3_object = bucket.object(part.s3_key)
          next unless check_existence(ibm_s3_object, part)
          next unless compare_checksum_metadata(ibm_s3_object, part)

          part.ok!
        end
      end

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
