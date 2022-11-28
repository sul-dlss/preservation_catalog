# frozen_string_literal: true

# TODO: this will be going away in favor of Dashboard::AuditService and ViewComponents

# helper methods for dashboard pertaining to audit functionality
module DashboardAuditHelper
  # used by audit_status partials
  def audits_ok?
    validate_moab_audit_ok? &&
      catalog_to_moab_audit_ok? &&
      moab_to_catalog_audit_ok? &&
      checksum_validation_audit_ok? &&
      catalog_to_archive_audit_ok?
  end

  # used by audit_status partials
  def validate_moab_audit_ok?
    # NOTE: unsure if there needs to be more checking of CompleteMoab.status_details for more statuses to figure this out
    (CompleteMoab.invalid_moab.count + CompleteMoab.online_moab_not_found.count).zero?
  end

  # used by audit_status partials
  def catalog_to_moab_audit_ok?
    # NOTE: unsure if there needs to be more checking of CompleteMoab.status_details for more statuses to figure this out
    !CompleteMoab.exists?(status: %w[online_moab_not_found unexpected_version_on_storage])
  end

  # used by audit_status partials
  def moab_to_catalog_audit_ok?
    # NOTE: unsure if there needs to be more checking of CompleteMoab.status_details for more statuses to figure this out
    # I believe if there's a moab that's not in the catalog, it is added by this audit.
    !any_complete_moab_errors?
  end

  # used by audit_status partials
  def checksum_validation_audit_ok?
    # NOTE: unsure if there needs to be more checking of CompleteMoab.status_details for more statuses to figure this out
    CompleteMoab.invalid_checksum.count.zero?
  end

  # used by audit_status partials
  def catalog_to_archive_audit_ok?
    !ZipPart.where.not(status: 'ok').exists?
  end
end
