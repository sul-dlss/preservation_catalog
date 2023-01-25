# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to ReplicationEndpointStatusComponent
  class ReplicationEndpointStatusComponent < ViewComponent::Base
    include Dashboard::ReplicationService

    with_collection_parameter :endpoints

    def initialize(endpoints:)
      @endpoint_name, @endpoint_info = endpoints
    end

    attr_reader :endpoint_info, :endpoint_name

    def replication_count
      endpoint_info[:replication_count]
    end

    def endpoint_replication_badge_class
      return OK_BADGE_CLASS if endpoint_replication_count_ok?(replication_count)

      NOT_OK_BADGE_CLASS
    end

    def endpoint_replication_status_label
      return OK_LABEL if endpoint_replication_count_ok?(replication_count)

      NOT_OK_LABEL
    end
  end
end
