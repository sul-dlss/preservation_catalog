# frozen_string_literal: true

module Replication
  # Service for auditing a ZippedMoabVersion's replication status
  class ZippedMoabVersionAuditService # rubocop:disable Metrics/ClassLength
    def self.call(...)
      new(...).call
    end

    def initialize(zipped_moab_version:, results:)
      @zipped_moab_version = zipped_moab_version
      @results = results
    end

    def call
      remediate_zip_part_count!

      status = check_zip_parts_created
      return update_status_to(status) if status

      status ||= check_zip_part_size_consistency
      status ||= check_zip_part_count_consistency
      status ||= check_zip_part_checksums
      status ||= check_zip_part_found
      status ||= :ok

      update_status_to(status)
    end

    private

    attr_reader :zipped_moab_version, :results

    delegate :zip_parts, :preserved_object, to: :zipped_moab_version

    def remediate_zip_part_count!
      # When the zip_part_count field was added, it was set to nil for existing ZippedMoabVersions.
      # Set it to the actual count of associated ZipParts if nil.
      return unless zipped_moab_version.zip_parts_count.nil?

      actual_count = zipped_moab_version.zip_parts.count
      zipped_moab_version.update!(zip_parts_count: actual_count) if actual_count.positive?
    end

    # @return [Boolean] true if the ZipPart count matches the zip_parts_count field
    def zip_part_count_mismatch?
      expected_count = zipped_moab_version.zip_parts_count
      actual_count = zipped_moab_version.zip_parts.count

      expected_count != actual_count
    end

    def check_zip_part_checksums
      checksum_mismatch_zip_parts = zip_parts_with_status(:checksum_mismatch)
      return if checksum_mismatch_zip_parts.empty?

      checksum_mismatch_zip_parts.each do |zip_part|
        add_result(Results::ZIP_PART_CHECKSUM_MISMATCH,
                   endpoint_name: zip_part.zipped_moab_version.zip_endpoint.endpoint_name,
                   s3_key: zip_part.s3_key,
                   md5: zip_part.md5,
                   replicated_checksum: zip_part.s3_part.metadata['checksum_md5'],
                   bucket_name: zip_part.s3_part.bucket_name)
      end
      :failed
    end

    def check_zip_part_found
      not_found_zip_parts = zip_parts_with_status(:not_found)
      return if not_found_zip_parts.empty?

      # If the status is currently :incomplete, report as ZIP_PARTS_NOT_ALL_REPLICATED
      # This state is expected; reporting doesn't indicate a problem.
      # If the status is something else, report as ZIP_PART_NOT_FOUND.
      if zipped_moab_version.incomplete?
        add_result(Results::ZIP_PARTS_NOT_ALL_REPLICATED)
      else
        not_found_zip_parts.each do |zip_part|
          add_result(Results::ZIP_PART_NOT_FOUND,
                     endpoint_name: zip_part.zipped_moab_version.zip_endpoint.endpoint_name,
                     s3_key: zip_part.s3_key,
                     bucket_name: zip_part.s3_part.bucket_name)
        end
      end
      :incomplete
    end

    def zip_parts_with_status(status)
      @zip_part_status_map ||= zip_parts.index_with do |zip_part|
        if !zip_part.s3_part.exists?
          :not_found
        elsif zip_part.s3_part.metadata['checksum_md5'] != zip_part.md5
          :checksum_mismatch
        else
          :ok
        end
      end
      zip_parts.select { |zip_part| @zip_part_status_map[zip_part] == status }
    end

    def add_result(code, **details)
      results.add_result(
        code,
        details.merge(
          version: zipped_moab_version.version,
          endpoint_name: zipped_moab_version.zip_endpoint.endpoint_name
        )
      )
    end

    # @return [Symbol, nil] returns status symbol if inconsistency found, else nil
    def check_zip_part_size_consistency
      total_part_size = zipped_moab_version.total_part_size
      moab_version_size = zipped_moab_version.druid_version_zip.moab_version_size
      return unless total_part_size < moab_version_size
      add_result(
        Results::ZIP_PARTS_SIZE_INCONSISTENCY,
        total_part_size: total_part_size, moab_version_size: moab_version_size
      )
      :failed
    end

    # @return [Symbol, nil] returns status symbol if inconsistency found, else nil
    def check_zip_part_count_consistency
      db_count = zipped_moab_version.zip_parts_count
      actual_count = zipped_moab_version.zip_parts.count
      return if db_count == actual_count
      add_result(
        Results::ZIP_PARTS_COUNT_DIFFERS_FROM_ACTUAL,
        db_count:, actual_count:
      )
      :failed
    end

    # @return [Symbol, nil] returns status symbol if zip parts were not created, else nil
    def check_zip_parts_created
      # If zip_parts_count is present, this is a zip part count consistency issue so not reporting here.
      return unless zip_parts.empty? && zipped_moab_version.zip_parts_count.nil?

      # If the current status is :created, this state is expected; reporting doesn't indicate a problem.
      # If the status is something else, this is unexpected.
      add_result(Results::ZIP_PARTS_NOT_CREATED)
      :created # ZippedMoabVersion has been created, but no ZipParts yet.
    end

    def update_status_to(new_status)
      # Setting status_updated_at to now to indicate that the status was checked, even if not changed.
      zipped_moab_version.update!(status: new_status, status_updated_at: Time.zone.now)
    end
  end
end
