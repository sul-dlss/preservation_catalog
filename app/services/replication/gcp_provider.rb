# frozen_string_literal: true

module Replication
  # The Application's configured interface to GCP's S3 compatible service.
  class GcpProvider < BaseProvider
    def initialize(...)
      super
      aws_client_args.merge!({ endpoint: endpoint_settings.endpoint_node })
    end
  end
end
