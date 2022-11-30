# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to ReplicationEndpointsComponent
  class ReplicationEndpointsComponent < ViewComponent::Base
    include Dashboard::MoabOnStorageService
    include Dashboard::ReplicationService
  end
end
