# frozen_string_literal: true

# code for validating Moab checksums
class ChecksumValidator
  include ::MoabValidationHandler

  attr_reader :bare_druid, :results, :complete_moab

  alias druid bare_druid
  delegate :moab_storage_root, to: :complete_moab
  delegate :storage_location, to: :moab_storage_root

  MANIFESTS = 'manifests'
  MANIFESTS_XML = 'manifestInventory.xml'
  MODIFIED = 'modified'
  ADDED = 'added'
  DELETED = 'deleted'
  FILES = 'files'

  def initialize(complete_moab)
    @complete_moab = complete_moab
    @bare_druid = complete_moab.preserved_object.druid
    @results = AuditResults.new(bare_druid, nil, moab_storage_root, 'validate_checksums')
  end

  def validate_checksums
    # check first thing to make sure the moab is present on disk, otherwise weird errors later
    unless File.exist?(object_dir)
      transaction_ok = ActiveRecordUtils.with_transaction_and_rescue(results) do
        mark_moab_not_found
        complete_moab.save!
      end
      results.remove_db_updated_results unless transaction_ok
      return results.report_results(Audit::Checksum.logger)
    end

    validate_manifest_inventories
    validate_signature_catalog

    # This is to deal with db connection timeouts.
    ActiveRecord::Base.clear_active_connections!

    transaction_ok = ActiveRecordUtils.with_transaction_and_rescue(results) do
      complete_moab.last_checksum_validation = Time.current
      if results.result_array.empty?
        results.add_result(AuditResults::MOAB_CHECKSUM_VALID)
        found_expected_version = moab.current_version_id == complete_moab.version
        set_status_as_seen_on_disk(found_expected_version)
        complete_moab.update_audit_timestamps(true, true)
        unless found_expected_version
          results.add_result(AuditResults::UNEXPECTED_VERSION, actual_version: moab.current_version_id, db_obj_name: 'CompleteMoab', db_obj_version: complete_moab.version)
        end
      else
        update_status('invalid_checksum')
      end
      complete_moab.save!
    end
    results.remove_db_updated_results unless transaction_ok

    results.report_results(Audit::Checksum.logger)
  end

  def validate_manifest_inventories
    moab.version_list.each { |moab_version| validate_manifest_inventory(moab_version) }
  end

  def validate_signature_catalog
    flag_unexpected_data_files
    validate_signature_catalog_listing
  end

  # override from MoabValidationHandler inclusion
  def can_validate_checksums?
    true
  end

  private

  def validate_signature_catalog_listing
    latest_signature_catalog_entries.each { |entry| validate_signature_catalog_entry(entry) }
  rescue Errno::ENOENT
    results.add_result(AuditResults::SIGNATURE_CATALOG_NOT_IN_MOAB, signature_catalog_path: latest_signature_catalog_path)
  rescue Nokogiri::XML::SyntaxError
    results.add_result(AuditResults::INVALID_MANIFEST, manifest_file_path: latest_signature_catalog_path)
  end

  def flag_unexpected_data_files
    data_files.each { |file| validate_against_signature_catalog(file) }
  end

  # Adds to the AuditResults object for any errors in checksum validation it encounters.
  # @param [Moab::StorageObjectVersion] moab_version
  def validate_manifest_inventory(moab_version)
    manifest_file_path = "#{moab_version.version_pathname}/#{MANIFESTS}/#{MANIFESTS_XML}"
    parse_verification_subentities(moab_version.verify_manifest_inventory)
  rescue Nokogiri::XML::SyntaxError
    results.add_result(AuditResults::INVALID_MANIFEST, manifest_file_path: manifest_file_path)
  rescue Errno::ENOENT
    results.add_result(AuditResults::MANIFEST_NOT_IN_MOAB, manifest_file_path: manifest_file_path)
  end

  # @param [Moab::VerificationResult] manifest_inventory_verification_result
  def parse_verification_subentities(manifest_inventory_verification_result)
    return if manifest_inventory_verification_result.verified
    manifest_inventory_verification_result.subentities.each do |subentity|
      parse_verification_subentity(subentity) unless subentity.verified
    end
  end

  # @param [Moab::VerificationResult] subentity
  def parse_verification_subentity(subentity)
    add_cv_result_for_modified_xml(subentity) if subentity.subsets[MODIFIED]
    add_cv_result_for_additions_in_xml(subentity) if subentity.subsets[ADDED]
    add_cv_result_for_deletions_in_xml(subentity) if subentity.subsets[DELETED]
  end

  def add_cv_result_for_modified_xml(subentity)
    subentity.subsets.dig(MODIFIED, FILES).each_value do |details|
      results.add_result(
        AuditResults::MOAB_FILE_CHECKSUM_MISMATCH,
        file_path: "#{subentity.details['other']}/#{details['basis_path']}",
        version: subentity.details['basis']
      )
    end
  end

  def add_cv_result_for_additions_in_xml(subentity)
    subentity.subsets.dig(ADDED, FILES).each_value do |details|
      results.add_result(
        AuditResults::FILE_NOT_IN_MANIFEST,
        file_path: "#{subentity.details['other']}/#{details['other_path']}",
        manifest_file_path: "#{subentity.details['other']}/#{MANIFESTS_XML}"
      )
    end
  end

  def add_cv_result_for_deletions_in_xml(subentity)
    subentity.subsets.dig(DELETED, FILES).each_value do |details|
      results.add_result(
        AuditResults::FILE_NOT_IN_MOAB,
        file_path: "#{subentity.details['other']}/#{details['basis_path']}",
        manifest_file_path: "#{subentity.details['other']}/#{MANIFESTS_XML}"
      )
    end
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

  # @return [String]
  def latest_signature_catalog_path
    @latest_signature_catalog_path ||= latest_moab_version.version_pathname.join(MANIFESTS, 'signatureCatalog.xml').to_s
  end

  # @return [Array<SignatureCatalogEntry>]
  def latest_signature_catalog_entries
    @latest_signature_catalog_entries ||= latest_moab_version.signature_catalog.entries
  rescue Errno::ENOENT, NoMethodError # e.g. latest_moab_version.signature_catalog is nil (signatureCatalog.xml does not exist)
    results.add_result(AuditResults::SIGNATURE_CATALOG_NOT_IN_MOAB, signature_catalog_path: latest_signature_catalog_path)
    []
  end

  def paths_from_signature_catalog
    @paths_from_signature_catalog ||= latest_signature_catalog_entries.map { |entry| signature_catalog_entry_path(entry) }
  end

  # @return [Moab::StorageObjectVersion]
  def latest_moab_version
    @latest_moab_version ||= moab.version_list.last
  end

  def validate_against_signature_catalog(data_file)
    absent_from_signature_catalog_data = { file_path: data_file, signature_catalog_path: latest_signature_catalog_path }
    results.add_result(AuditResults::FILE_NOT_IN_SIGNATURE_CATALOG, absent_from_signature_catalog_data) unless signature_catalog_has_file?(data_file)
  end

  def signature_catalog_has_file?(file)
    paths_from_signature_catalog.any? { |entry| entry == file }
  end

  def data_files
    files = []
    existing_data_dirs.each do |data_dir|
      Find.find(data_dir) { |path| files << path unless FileTest.directory?(path) }
    end
    files
  end

  def existing_data_dirs
    possible_data_content_dirs = moab.versions.map { |sov| sov.file_category_pathname('content') }
    possible_data_metadata_dirs = moab.versions.map { |sov| sov.file_category_pathname('metadata') }
    possible_data_dirs = possible_data_content_dirs + possible_data_metadata_dirs
    possible_data_dirs.select(&:exist?).map(&:to_s)
  end

  def calculated_signature(file)
    Moab::FileSignature.new.signature_from_file(Pathname(file))
  end
end
