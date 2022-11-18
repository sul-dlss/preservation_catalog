# frozen_string_literal: true

module Dashboard
  # methods for dashboard pertaining to AuditInformationComponent
  class AuditInformationComponent < ViewComponent::Base
    attr_reader :dashboard_audit_service, :dashboard_catalog_service, :dashboard_replication_service

    delegate :moab_audit_age_threshold,
             :num_moab_audits_older_than_threshold,
             :moab_audits_older_than_threshold?,
             :replication_audit_age_threshold,
             :num_replication_audits_older_than_threshold,
             :replication_audits_older_than_threshold?,
             to: :dashboard_audit_service

    delegate :num_complete_moab_not_ok,
             :any_complete_moab_errors?,
             :num_expired_checksum_validation,
             to: :dashboard_catalog_service

    delegate :num_replication_errors, to: :dashboard_replication_service

    def initialize
      @dashboard_audit_service = Dashboard::AuditService.new
      @dashboard_catalog_service = Dashboard::CatalogService.new
      @dashboard_replication_service = Dashboard::ReplicationService.new
      super
    end
  end
end
