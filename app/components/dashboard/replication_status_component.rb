# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to ReplicationStatusComponent
  class ReplicationStatusComponent < ViewComponent::Base
    include Dashboard::ReplicationService
    include Dashboard::CatalogService
  end
end
