# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to AuditStatusComponent
  class AuditStatusComponent < ViewComponent::Base
    include Dashboard::AuditService
  end
end
