# frozen_string_literal: true

module Audit
  # Service for validating Moab checksums on storage, updating the MoabRecord db record, and reporting results.
  class ChecksumValidator
    attr_reader :moab_record

    delegate :moab_storage_root, :preserved_object, to: :moab_record
    delegate :storage_location, to: :moab_storage_root
    delegate :druid, to: :preserved_object

    def initialize(moab_record, logger: nil)
      @moab_record = moab_record
      @logger = logger
    end

    def validate_checksums
      # check first thing to make sure the moab is present on storage, otherwise weird errors later
      return persist_db_transaction! { status_handler.mark_moab_not_found } if moab_on_storage_absent?

      # These will populate the results object
      validate_manifest_inventories
      validate_signature_catalog

      persist_db_transaction!(clear_connections: true) do
        moab_record.last_checksum_validation = Time.current
        if results.results.empty?
          results.add_result(AuditResults::MOAB_CHECKSUM_VALID)
          moab_record.update_audit_timestamps(true, true)

          validate_versions
        else
          status_handler.update_moab_record_status('invalid_checksum')
        end
      end
    end

    # @return [Moab::StorageObjectVersion]
    def latest_moab_storage_object_version
      @latest_moab_storage_object_version ||= moab_on_storage.version_list.last
    end

    # @return [Boolean] false if the moab exists, true otherwise
    def moab_on_storage_absent?
      !File.exist?(object_dir) || latest_moab_storage_object_version.nil?
    end

    def versions_match?
      moab_on_storage.current_version_id == moab_record.version
    end

    def validate_versions
      # validate_moab_on_storage_and_set_status will update results and moab_record
      status_handler.validate_moab_on_storage_and_set_status(found_expected_version: versions_match?,
                                                             moab_on_storage_validator: moab_on_storage_validator, caller_validates_checksums: true)

      return if versions_match?
      results.add_result(AuditResults::UNEXPECTED_VERSION,
                         actual_version: moab_on_storage.current_version_id,
                         db_obj_name: 'MoabRecord',
                         db_obj_version: moab_record.version)
    end

    def validate_manifest_inventories
      moab_on_storage.version_list.each { |moab_version| ManifestInventoryValidator.validate(moab_version: moab_version, checksum_validator: self) }
    end

    def validate_signature_catalog
      SignatureCatalogValidator.validate(checksum_validator: self)
    end

    def moab_on_storage_validator
      @moab_on_storage_validator ||= MoabOnStorage::Validator.new(moab: moab_on_storage, audit_results: results)
    end

    def status_handler
      @status_handler ||= StatusHandler.new(audit_results: results, moab_record: moab_record)
    end

    def moab_on_storage
      @moab_on_storage ||= MoabOnStorage.moab(storage_location: storage_location, druid: druid)
    end

    def results
      @results ||= AuditResults.new(druid: druid, moab_storage_root: moab_storage_root, actual_version: moab_on_storage.current_version_id,
                                    check_name: 'validate_checksums')
    end

    def persist_db_transaction!(clear_connections: false)
      # This is to deal with db connection timeouts.
      ActiveRecord::Base.clear_active_connections! if clear_connections

      transaction_ok = ActiveRecordUtils.with_transaction_and_rescue(results) do
        yield if block_given?
        moab_record.save!
      end
      results.remove_db_updated_results unless transaction_ok
      AuditResultsReporter.report_results(audit_results: results, logger: logger)
    end

    def object_dir
      @object_dir ||= MoabOnStorage.object_dir(storage_location: storage_location, druid: druid)
    end

    def logger
      @logger ||= Logger.new($stdout).extend(ActiveSupport::Logger.broadcast(Logger.new(Rails.root.join('log', 'cv.log'))))
    end

    # Validates files on storage against the manifest inventory
    class ManifestInventoryValidator
      MANIFESTS = 'manifests'
      MANIFESTS_XML = 'manifestInventory.xml'
      MODIFIED = 'modified'
      ADDED = 'added'
      DELETED = 'deleted'
      FILES = 'files'

      def self.validate(moab_version:, checksum_validator:)
        new(moab_version: moab_version, checksum_validator: checksum_validator).validate
      end

      def initialize(moab_version:, checksum_validator:)
        @moab_version = moab_version
        @checksum_validator = checksum_validator
      end

      # Adds to the AuditResults object for any errors in checksum validation it encounters.
      def validate
        return if manifest_inventory_verification_result.verified

        manifest_inventory_verification_result.subentities.each do |subentity|
          parse_verification_subentity(subentity) unless subentity.verified
        end
      rescue Nokogiri::XML::SyntaxError
        results.add_result(AuditResults::INVALID_MANIFEST, manifest_file_path: manifest_file_path)
      rescue Errno::ENOENT
        results.add_result(AuditResults::MANIFEST_NOT_IN_MOAB, manifest_file_path: manifest_file_path)
      end

      private

      attr_reader :moab_version, :checksum_validator

      delegate :results, to: :checksum_validator

      def manifest_file_path
        @manifest_file_path ||= "#{moab_version.version_pathname}/#{MANIFESTS}/#{MANIFESTS_XML}"
      end

      def manifest_inventory_verification_result
        @manifest_inventory_verification_result ||= moab_version.verify_manifest_inventory
      end

      # @param [Moab::VerificationResult] subentity
      def parse_verification_subentity(subentity)
        add_result_for_modified_xml(subentity) if subentity.subsets[MODIFIED]
        add_result_for_additions_in_xml(subentity) if subentity.subsets[ADDED]
        add_result_for_deletions_in_xml(subentity) if subentity.subsets[DELETED]
      end

      def add_result_for_modified_xml(subentity)
        subentity.subsets.dig(MODIFIED, FILES).each_value do |details|
          results.add_result(
            AuditResults::MOAB_FILE_CHECKSUM_MISMATCH,
            file_path: "#{subentity.details['other']}/#{details['basis_path']}",
            version: subentity.details['basis']
          )
        end
      end

      def add_result_for_additions_in_xml(subentity)
        subentity.subsets.dig(ADDED, FILES).each_value do |details|
          results.add_result(
            AuditResults::FILE_NOT_IN_MANIFEST,
            file_path: "#{subentity.details['other']}/#{details['other_path']}",
            manifest_file_path: "#{subentity.details['other']}/#{MANIFESTS_XML}"
          )
        end
      end

      def add_result_for_deletions_in_xml(subentity)
        subentity.subsets.dig(DELETED, FILES).each_value do |details|
          results.add_result(
            AuditResults::FILE_NOT_IN_MOAB,
            file_path: "#{subentity.details['other']}/#{details['basis_path']}",
            manifest_file_path: "#{subentity.details['other']}/#{MANIFESTS_XML}"
          )
        end
      end
    end

    # Validates files on storage against the signature catalog
    class SignatureCatalogValidator
      MANIFESTS = 'manifests'

      def self.validate(checksum_validator:)
        new(checksum_validator: checksum_validator).validate
      end

      def initialize(checksum_validator:)
        @checksum_validator = checksum_validator
      end

      def validate
        flag_unexpected_data_files
        validate_signature_catalog_listing
      end

      private

      attr_reader :checksum_validator

      delegate :moab_on_storage, :results, :latest_moab_storage_object_version, :object_dir, to: :checksum_validator

      def flag_unexpected_data_files
        data_files.each { |file| validate_against_signature_catalog(file) }
      end

      def data_files
        @data_files ||= [].tap do |files|
          existing_data_dirs.each do |data_dir|
            Find.find(data_dir) { |path| files << path unless FileTest.directory?(path) }
          end
        end
      end

      def existing_data_dirs
        possible_data_content_dirs = moab_on_storage.versions.map { |sov| sov.file_category_pathname('content') }
        possible_data_metadata_dirs = moab_on_storage.versions.map { |sov| sov.file_category_pathname('metadata') }
        possible_data_dirs = possible_data_content_dirs + possible_data_metadata_dirs
        possible_data_dirs.select(&:exist?).map(&:to_s)
      end

      def validate_against_signature_catalog(data_file)
        return if signature_catalog_has_file?(data_file)

        absent_from_signature_catalog_data = { file_path: data_file, signature_catalog_path: latest_signature_catalog_path }

        results.add_result(AuditResults::FILE_NOT_IN_SIGNATURE_CATALOG,
                           absent_from_signature_catalog_data)
      end

      def latest_signature_catalog_path
        @latest_signature_catalog_path ||= latest_moab_storage_object_version.version_pathname.join(MANIFESTS, 'signatureCatalog.xml').to_s
      end

      def paths_from_signature_catalog
        @paths_from_signature_catalog ||= latest_signature_catalog_entries.map { |entry| signature_catalog_entry_path(entry) }
      end

      def signature_catalog_has_file?(file)
        paths_from_signature_catalog.any? { |entry| entry == file }
      end

      # @return [Array<SignatureCatalogEntry>]
      def latest_signature_catalog_entries
        @latest_signature_catalog_entries ||= latest_moab_storage_object_version.signature_catalog.entries
      rescue Errno::ENOENT, NoMethodError # e.g. latest_moab_storage_object_version.signature_catalog is nil (signatureCatalog.xml does not exist)
        results.add_result(AuditResults::SIGNATURE_CATALOG_NOT_IN_MOAB, signature_catalog_path: latest_signature_catalog_path)
        []
      rescue Nokogiri::XML::SyntaxError => e
        results.add_result(AuditResults::INVALID_MANIFEST, manifest_file_path: latest_signature_catalog_path, addl: e.inspect)
        []
      end

      def validate_signature_catalog_listing
        latest_signature_catalog_entries.each { |entry| validate_signature_catalog_entry(entry) }
      rescue Errno::ENOENT
        results.add_result(AuditResults::SIGNATURE_CATALOG_NOT_IN_MOAB, signature_catalog_path: latest_signature_catalog_path)
      rescue Nokogiri::XML::SyntaxError
        results.add_result(AuditResults::INVALID_MANIFEST, manifest_file_path: latest_signature_catalog_path)
      end

      def validate_signature_catalog_entry(entry)
        unless entry.signature.eql?(calculated_signature(signature_catalog_entry_path(entry)))
          mismatch_error_data = { file_path: signature_catalog_entry_path(entry), version: entry.version_id }
          results.add_result(AuditResults::MOAB_FILE_CHECKSUM_MISMATCH, mismatch_error_data)
        end
      rescue Errno::ENOENT
        absent_from_moab_data = { manifest_file_path: latest_signature_catalog_path,
                                  file_path: signature_catalog_entry_path(entry) }
        results.add_result(AuditResults::FILE_NOT_IN_MOAB, absent_from_moab_data)
      end

      # @return [String]
      def signature_catalog_entry_path(entry)
        @signature_catalog_entry_paths ||= {}
        @signature_catalog_entry_paths[entry] ||= "#{object_dir}/#{entry.storage_path}"
      end

      def calculated_signature(file)
        Moab::FileSignature.new.signature_from_file(Pathname(file))
      end
    end
  end
end
