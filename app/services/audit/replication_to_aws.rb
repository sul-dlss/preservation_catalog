# frozen_string_literal: true

module Audit
  # Methods for auditing the state of a ZippedMoabVersion on an AWS S3 endpoint.
  # @note this class name appears in the configuration for the endpoints for which it audits content.
  #   Please update the configs for the various environments if it's renamed or moved.
  class ReplicationToAws < ReplicationToEndpointBase
    def s3_provider_class
      ::Replication::AwsProvider
    end
  end
end
