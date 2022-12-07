# frozen_string_literal: true

module Audit
  # Methods for auditing the state of a ZippedMoabVersion on an IBM S3 compatible endpoint.
  # @note this class name appears in the configuration for the endpoints for which it audits content.
  #   Please update the configs for the various environments if it's renamed or moved.
  class ReplicationToIbm < ReplicationToEndpointBase
    def s3_provider_class
      ::Replication::IbmProvider
    end
  end
end
