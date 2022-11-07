# frozen_string_literal: true

# helper methods for dashboard
module DashboardHelper # rubocop:disable Metrics/ModuleLength
  # CompleteMoab.last_version_audit is the most recent of 3 separate audits:
  #   moab_to_catalog - all CompleteMoabs are queued for this on the 1st of the month
  #   catalog_to_moab - all CompleteMoabs are queued for this on the 15th of the month
  #   checksum_validation - CompleteMoabs with expired checksums are queued weekly;  they expire after 90 days
  # 18 days gives a little slop for either of the first 2 audit queues to die down.
  MOAB_LAST_VERSION_AUDIT_THRESHOLD = 18.days

  REPLICATION_AUDIT_THRESHOLD = 90.days # meant to be the same as PreservationPolicy.archive_ttl

  def catalog_ok?
    num_preserved_objects == num_complete_moabs &&
      num_object_versions_per_preserved_object == num_object_versions_per_complete_moab
  end

  def replication_ok?
    replication_info.each_value do |info|
      return false if info[1] != num_object_versions_per_preserved_object
    end
    true
  end

  def validate_moab_audit_ok?
    # NOTE: unsure if there needs to be more checking of CompleteMoab.status_details for more statuses to figure this out
    (CompleteMoab.invalid_moab.count + CompleteMoab.online_moab_not_found.count).zero?
  end

  def catalog_to_moab_audit_ok?
    # NOTE: unsure if there needs to be more checking of CompleteMoab.status_details for more statuses to figure this out
    (CompleteMoab.online_moab_not_found.count + CompleteMoab.unexpected_version_on_storage.count).zero?
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
    (ZipPart.count - ZipPart.ok.count).zero?
  end

  def storage_root_info
    storage_root_info = {}
    MoabStorageRoot.all.each do |storage_root|
      storage_root_info[storage_root.name] =
        [
          storage_root.storage_location,
          "#{storage_root.complete_moabs.sum(:size).fdiv(Numeric::TERABYTE).round(2)} Tb",
          "#{(storage_root.complete_moabs.average(:size) || 0).fdiv(Numeric::MEGABYTE).round(2)} Mb",
          storage_root.complete_moabs.count,
          CompleteMoab::STATUSES.map { |status| storage_root.complete_moabs.where(status: status).count },
          storage_root.complete_moabs.fixity_check_expired.count
        ].flatten
    end
    storage_root_info
  end

  # @return [Array<Integer>] totals of counts from each storage root for:
  #   total of counts of each CompleteMoab status (ok, invalid_checksum, etc.)
  #   total of counts of fixity_check_expired
  #   total of complete_moab counts - this is last element in array due to index shift to skip storage_location and stored size
  def storage_root_totals
    return [0] if storage_root_info.values.size.zero?

    totals = Array.new(storage_root_info.values.first.size - 3, 0)
    storage_root_info.each_key do |root_name|
      storage_root_info[root_name][3..].each_with_index do |count, index|
        totals[index] += count
      end
    end
    totals
  end

  def storage_root_total_count
    storage_root_totals.first
  end

  def storage_root_total_ok_count
    storage_root_totals[1]
  end

  def complete_moab_total_size
    "#{CompleteMoab.sum(:size).fdiv(Numeric::TERABYTE).round(2)} Tb"
  end

  def complete_moab_average_size
    "#{CompleteMoab.average(:size).fdiv(Numeric::MEGABYTE).round(2)} Mb" unless num_complete_moabs.zero?
  end

  def complete_moab_status_counts
    CompleteMoab::STATUSES.map { |status| CompleteMoab.where(status: status).count }
  end

  def status_labels
    CompleteMoab::STATUSES.map { |status| status.tr('_', ' ') }
  end

  def moab_audit_age_threshold
    (DateTime.now - MOAB_LAST_VERSION_AUDIT_THRESHOLD).to_s
  end

  def num_moab_audits_older_than_threshold
    CompleteMoab.least_recent_version_audit(moab_audit_age_threshold).count
  end

  def moab_audits_older_than_threshold?
    num_moab_audits_older_than_threshold.positive?
  end

  def num_expired_checksum_validation
    CompleteMoab.fixity_check_expired.count
  end

  def any_complete_moab_errors?
    num_complete_moab_not_ok.positive?
  end

  def num_complete_moab_not_ok
    num_complete_moabs - CompleteMoab.ok.count
  end

  def replication_info
    replication_info = {}
    ZipEndpoint.all.each do |zip_endpoint|
      replication_info[zip_endpoint.endpoint_name] =
        [
          zip_endpoint.delivery_class,
          ZippedMoabVersion.where(zip_endpoint_id: zip_endpoint.id).count
        ].flatten
    end
    replication_info
  end

  def zip_part_suffixes
    ZipPart.group(:suffix).count
  end

  def zip_parts_total_size
    "#{ZipPart.sum(:size).fdiv(Numeric::TERABYTE).round(2)} Tb"
  end

  def num_replication_errors
    ZipPart.count - ZipPart.ok.count
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

  def num_preserved_objects
    PreservedObject.count
  end

  def preserved_object_highest_version
    preserved_object_ordered_version_counts.keys.last
  end

  # total number of object versions according to PreservedObject table
  def num_object_versions_per_preserved_object
    total_version_count(preserved_object_ordered_version_counts)
  end

  def average_version_per_preserved_object
    num_object_versions_per_preserved_object.fdiv(num_preserved_objects).to_f.round(2) unless num_preserved_objects.zero?
  end

  def num_complete_moabs
    CompleteMoab.count
  end

  def complete_moab_highest_version
    complete_moab_ordered_version_counts.keys.last
  end

  # total number of object versions according to CompleteMoab table
  def num_object_versions_per_complete_moab
    total_version_count(complete_moab_ordered_version_counts)
  end

  def average_version_per_complete_moab
    num_object_versions_per_complete_moab.fdiv(num_complete_moabs).round(2) unless num_complete_moabs.zero?
  end

  private

  def preserved_object_ordered_version_counts
    PreservedObject.group(:current_version).count.sort.to_h
  end

  def complete_moab_ordered_version_counts
    CompleteMoab.group(:version).count.sort.to_h
  end

  def total_version_count(version_counts)
    result = 0
    version_counts.each { |version, count_for_version| result += version * count_for_version }
    result
  end
end
