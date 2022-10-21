# frozen_string_literal: true

# code for validating Moab checksums
class ChecksumValidator
  attr_reader :results, :complete_moab

  delegate :moab_storage_root, :preserved_object, to: :complete_moab
  delegate :storage_location, to: :moab_storage_root
  delegate :druid, to: :preserved_object
  delegate :moab, :object_dir, to: :moab_validator

  def initialize(complete_moab)
    @complete_moab = complete_moab
    @results = AuditResults.new(druid, nil, moab_storage_root, 'validate_checksums', logger: Audit::Checksum.logger)
    # TODO: fix fragile interdependence, MoabValidator wants AuditResults instance, but we want MoabValidator#moab.current_version_id
    # in that AuditResults instance.  so set AuditResults#actual_version after both instances have been created.
    @results.actual_version = moab.current_version_id
  end

  def validate_checksums
    # check first thing to make sure the moab is present on disk, otherwise weird errors later
    return persist_db_transaction! { moab_validator.mark_moab_not_found } if moab_absent?

    # These will populate the results object
    validate_manifest_inventories
    validate_signature_catalog

    persist_db_transaction!(clear_connections: true) do
      complete_moab.last_checksum_validation = Time.current
      if results.result_array.empty?
        results.add_result(AuditResults::MOAB_CHECKSUM_VALID)
        complete_moab.update_audit_timestamps(true, true)

        validate_versions
      else
        update_complete_moab_status('invalid_checksum')
      end
    end
  end

  # @return [Moab::StorageObjectVersion]
  def latest_moab_storage_object_version
    @latest_moab_storage_object_version ||= moab.version_list.last
  end

  private

  # @return [Boolean] false if the moab exists, true otherwise
  def moab_absent?
    !File.exist?(object_dir) || latest_moab_storage_object_version.nil?
  end

  def update_complete_moab_status(status)
    moab_validator.update_status(status)
  end

  # Moab and complete moab versions match?
  def versions_match?
    moab.current_version_id == complete_moab.version
  end

  def validate_versions
    # set_status_as_seen_on_disk will update results and complete_moab
    moab_validator.set_status_as_seen_on_disk(versions_match?)

    return if versions_match?
    results.add_result(AuditResults::UNEXPECTED_VERSION,
                       actual_version: moab.current_version_id,
                       db_obj_name: 'CompleteMoab',
                       db_obj_version: complete_moab.version)
  end

  def validate_manifest_inventories
    moab.version_list.each { |moab_version| ManifestInventoryValidator.validate(moab_version: moab_version, checksum_validator: self) }
  end

  def validate_signature_catalog
    SignatureCatalogValidator.validate(checksum_validator: self)
  end

  def moab_validator
    @moab_validator ||= MoabValidator.new(druid: druid,
                                          storage_location: storage_location,
                                          results: results,
                                          complete_moab: complete_moab,
                                          caller_validates_checksums: true)
  end

  def persist_db_transaction!(clear_connections: false)
    # This is to deal with db connection timeouts.
    ActiveRecord::Base.clear_active_connections! if clear_connections

    transaction_ok = ActiveRecordUtils.with_transaction_and_rescue(results) do
      yield if block_given?
      complete_moab.save!
    end
    results.remove_db_updated_results unless transaction_ok
    results.report_results
  end

  # Validates files on disk against the manifest inventory
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

  # Validates files on disk against the signature catalog
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

    delegate :moab, :results, :latest_moab_storage_object_version, :object_dir, to: :checksum_validator

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
      possible_data_content_dirs = moab.versions.map { |sov| sov.file_category_pathname('content') }
      possible_data_metadata_dirs = moab.versions.map { |sov| sov.file_category_pathname('metadata') }
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
