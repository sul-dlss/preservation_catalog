# frozen_string_literal: true

module Audit
  # Methods for auditing the state of a ZippedMoabVersion on an S3 compatible endpoint.
  # @note this class name appears in the configuration for the endpoints for which it audits content.
  #   Please update the configs for the various environments if it's renamed or moved.
  class ReplicationToGcp < ReplicationToEndpointBase
    def s3_provider_class
      ::Replication::GcpProvider
    end
  end
end
