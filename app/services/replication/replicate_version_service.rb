# frozen_string_literal: true

module Replication
  # Performs replication of a specific version of a PreservedObject
  class ReplicateVersionService
    def self.call(...)
      new(...).call
    end

    def initialize(preserved_object:, version:)
      @preserved_object = preserved_object
      @version = version
      Honeybadger.context(druid:, version: version)
    end

    def call # rubocop:disable Metrics/AbcSize
      # Skip if there are no created or incomplete ZippedMoabVersion for the version
      return unless zipped_moab_versions.created.exists? || zipped_moab_versions.incomplete.exists?

      # Skip if the MoabRecord is not ok
      return unless preserved_object.moab_record.ok?

      # If there is a zip, makes sure it is complete.
      # If it is not complete or not present, creates it.
      create_zip_if_necessary

      zipped_moab_versions.incomplete.each do |zipped_moab_version|
        reset_to_created!(zipped_moab_version) if no_zip_parts_on_endpoint?(zipped_moab_version)
        # Check that the md5s for the local zip part files match those recorded in the db
        check_zip_parts_to_zip_file(zipped_moab_version)
      end

      zipped_moab_versions.created.each do |zipped_moab_version|
        populate_zip_parts!(zipped_moab_version)
      end

      replicate_incomplete_zipped_moab_versions

      # Delete the local zip part files
      druid_version_zip.cleanup_zip_parts!
    end

    private

    attr_reader :preserved_object, :version

    delegate :druid, to: :preserved_object

    def zipped_moab_versions
      preserved_object.zipped_moab_versions.where(version:)
    end

    def druid_version_zip
      @druid_version_zip ||= zipped_moab_versions.first.druid_version_zip
    end

    def create_zip_if_necessary
      return if druid_version_zip.complete?

      druid_version_zip.cleanup_zip_parts!
      druid_version_zip.create_zip!
    end

    def reset_to_created!(zipped_moab_version)
      ZippedMoabVersion.transaction do
        zipped_moab_version.zip_parts.destroy_all
        zipped_moab_version.update!(status: 'created', status_details: 'no zip part files found on endpoint')
      end
    end

    # @return [Boolean] true if there are no zip part files on the endpoint for the ZippedMoabVersion
    def no_zip_parts_on_endpoint?(zipped_moab_version)
      zipped_moab_version.zip_parts.none? { |zip_part| zip_part.s3_part.exists? }
    end

    def check_zip_parts_to_zip_file(zipped_moab_version)
      results = Replication::ZipPartsToZipFilesAuditService.call(zipped_moab_version:)
      return if results.empty?

      ResultsReporter.report_results(results:)
      zipped_moab_version.update!(status: 'failed', status_details: results.to_s, status_updated_at: Time.current)
    end

    def populate_zip_parts!(zipped_moab_version)
      ZippedMoabVersion.transaction do
        druid_version_zip.druid_version_zip_parts.each do |druid_version_zip_part|
          zipped_moab_version.zip_parts.create!(
            suffix: druid_version_zip_part.extname,
            size: druid_version_zip_part.size,
            md5: druid_version_zip_part.read_md5
          )
        end
        zipped_moab_version.update!(zip_parts_count: zipped_moab_version.zip_parts.count)
        zipped_moab_version.update!(status: 'incomplete', status_details: 'zip parts created, replication pending')
      end
    end

    def replicate_incomplete_zipped_moab_versions
      zipped_moab_versions.incomplete.each do |zipped_moab_version|
        error_results = []
        zipped_moab_version.zip_parts.each do |zip_part|
          if (results = Replication::ReplicateZipPartService.call(zip_part:)).present?
            ResultsReporter.report_results(results:)
            error_results << results
          end
        end

        if error_results.empty?
          zipped_moab_version.update!(status: 'ok', status_details: 'replication complete')
          send_dsa_event(zipped_moab_version)
        else
          zipped_moab_version.update!(status: 'failed', status_details: error_results.map(&:to_s).join('; '))
        end
      end
    end

    def send_dsa_event(zipped_moab_version)
      parts_info = zipped_moab_version.zip_parts.order(:suffix).map do |part|
        { s3_key: part.s3_key, size: part.size, md5: part.md5 }
      end

      Dor::Event::Client.create(
        druid: "druid:#{druid}",
        type: 'druid_version_replicated',
        data: {
          host: Socket.gethostname,
          invoked_by: 'preservation-catalog',
          version: zipped_moab_version.version,
          endpoint_name: zipped_moab_version.zip_endpoint.endpoint_name,
          parts_info:
        }
      )
    end
  end
end
