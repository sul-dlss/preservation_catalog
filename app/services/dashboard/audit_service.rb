# frozen_string_literal: true

# services for dashboard
module Dashboard
  # methods pertaining to audit functionality for dashboard
  module AuditService
    include MoabOnStorageService
    include InstrumentationSupport

    # MoabRecord.last_version_audit is the most recent of 3 separate audits:
    #   moab_to_catalog - all MoabRecords are queued for this on the 1st of the month
    #   catalog_to_moab - all MoabRecords are queued for this on the 15th of the month
    #   checksum_validation - MoabRecords with expired checksums are queued weekly;  they expire after 90 days
    # 18 days gives a little slop for either of the first 2 audit queues to die down.
    MOAB_LAST_VERSION_AUDIT_THRESHOLD = 18.days

    REPLICATION_AUDIT_THRESHOLD = 90.days # meant to be the same as Settings.preservation_policy.archive_ttl

    def audits_ok?
      validate_moab_audit_ok? &&
        catalog_to_moab_audit_ok? &&
        moab_to_catalog_audit_ok? &&
        moab_checksum_validation_audit_ok? &&
        catalog_to_archive_audit_ok?
    end

    def validate_moab_audit_ok?
      # NOTE: unsure if there needs to be more checking of MoabRecord.status_details for more statuses to figure this out
      (MoabRecord.invalid_moab.annotate(caller).count + MoabRecord.moab_on_storage_not_found.annotate(caller).count).zero?
    end

    def catalog_to_moab_audit_ok?
      # NOTE: unsure if there needs to be more checking of MoabRecord.status_details for more statuses to figure this out
      !MoabRecord.all.annotate(caller).exists?(status: %w[moab_on_storage_not_found unexpected_version_on_storage])
    end

    def moab_to_catalog_audit_ok?
      # NOTE: unsure if there needs to be more checking of MoabRecord.status_details for more statuses to figure this out
      # I believe if there's a moab that's not in the catalog, it is added by this audit.
      !any_moab_record_errors?
    end

    def moab_checksum_validation_audit_ok?
      # NOTE: unsure if there needs to be more checking of MoabRecord.status_details for more statuses to figure this out
      MoabRecord.invalid_checksum.annotate(caller).count.zero?
    end

    def catalog_to_archive_audit_ok?
      !ZipPart.where.not(status: 'ok').annotate(caller).exists?
    end

    def moab_audit_age_threshold
      (DateTime.now - MOAB_LAST_VERSION_AUDIT_THRESHOLD).to_s
    end

    def num_moab_audits_older_than_threshold
      MoabRecord.version_audit_expired(moab_audit_age_threshold).annotate(caller).count
    end

    def moab_audits_older_than_threshold?
      num_moab_audits_older_than_threshold.positive?
    end

    def replication_audit_age_threshold
      (DateTime.now - REPLICATION_AUDIT_THRESHOLD).to_s
    end

    def num_replication_audits_older_than_threshold
      PreservedObject.archive_check_expired.annotate(caller).count
    end

    def replication_audits_older_than_threshold?
      num_replication_audits_older_than_threshold.positive?
    end
  end
end
