# frozen_string_literal: true

# services for dashboard
module Dashboard
  # methods pertaining to audit functionality for dashboard
  module AuditService
    include CatalogService

    # CompleteMoab.last_version_audit is the most recent of 3 separate audits:
    #   moab_to_catalog - all CompleteMoabs are queued for this on the 1st of the month
    #   catalog_to_moab - all CompleteMoabs are queued for this on the 15th of the month
    #   checksum_validation - CompleteMoabs with expired checksums are queued weekly;  they expire after 90 days
    # 18 days gives a little slop for either of the first 2 audit queues to die down.
    MOAB_LAST_VERSION_AUDIT_THRESHOLD = 18.days

    REPLICATION_AUDIT_THRESHOLD = 90.days # meant to be the same as PreservationPolicy.archive_ttl

    def audits_ok?
      validate_moab_audit_ok? &&
        catalog_to_moab_audit_ok? &&
        moab_to_catalog_audit_ok? &&
        checksum_validation_audit_ok? &&
        catalog_to_archive_audit_ok?
    end

    def validate_moab_audit_ok?
      # NOTE: unsure if there needs to be more checking of CompleteMoab.status_details for more statuses to figure this out
      (CompleteMoab.invalid_moab.count + CompleteMoab.online_moab_not_found.count).zero?
    end

    def catalog_to_moab_audit_ok?
      # NOTE: unsure if there needs to be more checking of CompleteMoab.status_details for more statuses to figure this out
      !CompleteMoab.exists?(status: %w[online_moab_not_found unexpected_version_on_storage])
    end

    def moab_to_catalog_audit_ok?
      # NOTE: unsure if there needs to be more checking of CompleteMoab.status_details for more statuses to figure this out
      # I believe if there's a moab that's not in the catalog, it is added by this audit.
      !any_complete_moab_errors?
    end

    def checksum_validation_audit_ok?
      # NOTE: unsure if there needs to be more checking of CompleteMoab.status_details for more statuses to figure this out
      CompleteMoab.invalid_checksum.count.zero?
    end

    def catalog_to_archive_audit_ok?
      !ZipPart.where.not(status: 'ok').exists?
    end

    def moab_audit_age_threshold
      (DateTime.now - MOAB_LAST_VERSION_AUDIT_THRESHOLD).to_s
    end

    def num_moab_audits_older_than_threshold
      CompleteMoab.version_audit_expired(moab_audit_age_threshold).count
    end

    def moab_audits_older_than_threshold?
      num_moab_audits_older_than_threshold.positive?
    end

    def replication_audit_age_threshold
      (DateTime.now - REPLICATION_AUDIT_THRESHOLD).to_s
    end

    def num_replication_audits_older_than_threshold
      PreservedObject.archive_check_expired.count
    end

    def replication_audits_older_than_threshold?
      num_replication_audits_older_than_threshold.positive?
    end
  end
end
