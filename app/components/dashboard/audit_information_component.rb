# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to AuditInformationComponent
  class AuditInformationComponent < ViewComponent::Base
    include Dashboard::AuditService
    include Dashboard::MoabOnStorageService
    include Dashboard::ReplicationService
  end
end
