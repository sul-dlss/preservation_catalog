# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to ReplicationFilesComponent
  class ReplicationFilesComponent < ViewComponent::Base
    include Dashboard::ReplicationService
  end
end
