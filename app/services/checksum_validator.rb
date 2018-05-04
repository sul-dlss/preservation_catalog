# code for validating Moab checksums
class ChecksumValidator
  include ::MoabValidationHandler

  attr_reader :results, :endpoint, :full_druid, :preserved_copy, :bare_druid

  alias druid bare_druid
  delegate :storage_location, to: :endpoint

  DATA = 'data'.freeze
  MANIFESTS = 'manifests'.freeze
  MANIFESTS_XML = 'manifestInventory.xml'.freeze
  SIGNATURE_XML = 'signatureCatalog.xml'.freeze
  GROUP_DIFF = 'group_differences'.freeze
  SUBSETS = 'subsets'.freeze
  MODIFIED = 'modified'.freeze
  ADDED = 'added'.freeze
  DELETED = 'deleted'.freeze
  FILES = 'files'.freeze

  def initialize(preserved_copy, endpoint_name)
    @preserved_copy = preserved_copy
    @bare_druid = preserved_copy.preserved_object.druid
    @endpoint = Endpoint.find_by(endpoint_name: endpoint_name)
    @results = AuditResults.new(bare_druid, nil, endpoint)
    @full_druid = "druid:#{bare_druid}"
  end

  def validate_checksums
    validate_manifest_inventories
    validate_signature_catalog

    transaction_ok = ActiveRecordUtils.with_transaction_and_rescue(results) do
      preserved_copy.last_checksum_validation = Time.current
      if results.result_array.empty?
        results.add_result(AuditResults::MOAB_CHECKSUM_VALID)
        found_expected_version = moab.current_version_id == preserved_copy.version
        set_status_as_seen_on_disk(found_expected_version)
      else
        update_status(PreservedCopy::INVALID_CHECKSUM_STATUS)
      end
      preserved_copy.save!
    end
    results.remove_db_updated_results unless transaction_ok

    results.report_results
  end

  def validate_manifest_inventories
    moab_storage_object.version_list.each { |moab_version| validate_manifest_inventory(moab_version) }
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

  # This method adds to the AuditResults object for any errors in checksum validation it encounters.
  def validate_manifest_inventory(moab_version)
    manifest_file_path = "#{moab_version.version_pathname}/#{MANIFESTS}/#{MANIFESTS_XML}"
    begin
      verification_result = moab_version.verify_manifest_inventory
      parse_verification_subentities(verification_result)
    rescue Nokogiri::XML::SyntaxError
      results.add_result(AuditResults::INVALID_MANIFEST, manifest_file_path: manifest_file_path)
    rescue Errno::ENOENT
      results.add_result(AuditResults::MANIFEST_NOT_IN_MOAB, manifest_file_path: manifest_file_path)
    end
  end

  def parse_verification_subentities(manifest_inventory_verification_result)
    return if manifest_inventory_verification_result.verified
    manifest_inventory_verification_result.subentities.each do |subentity|
      parse_verification_subentity(subentity) unless subentity.verified
    end
  end

  def parse_verification_subentity(subentity)
    add_cv_result_for_modified_xml(subentity) if subentity.details.dig(GROUP_DIFF, MANIFESTS, SUBSETS, MODIFIED)
    add_cv_result_for_additions_in_xml(subentity) if subentity.details.dig(GROUP_DIFF, MANIFESTS, SUBSETS, ADDED)
    add_cv_result_for_deletions_in_xml(subentity) if subentity.details.dig(GROUP_DIFF, MANIFESTS, SUBSETS, DELETED)
  end

  def add_cv_result_for_modified_xml(subentity)
    subentity.details.dig(GROUP_DIFF, MANIFESTS, SUBSETS, MODIFIED, FILES).each_value do |details|
      mismatch_error_data = {
        file_path: "#{subentity.details['other']}/#{details['basis_path']}",
        version: subentity.details['basis']
      }
      results.add_result(AuditResults::MOAB_FILE_CHECKSUM_MISMATCH, mismatch_error_data)
    end
  end

  def add_cv_result_for_additions_in_xml(subentity)
    subentity.details.dig(GROUP_DIFF, MANIFESTS, SUBSETS, ADDED, FILES).each_value do |details|
      absent_from_manifest_data = {
        file_path: "#{subentity.details['other']}/#{details['other_path']}",
        manifest_file_path: "#{subentity.details['other']}/#{MANIFESTS_XML}"
      }
      results.add_result(AuditResults::FILE_NOT_IN_MANIFEST, absent_from_manifest_data)
    end
  end

  def add_cv_result_for_deletions_in_xml(subentity)
    subentity.details.dig(GROUP_DIFF, MANIFESTS, SUBSETS, DELETED, FILES).each_value do |details|
      absent_from_moab_data = {
        manifest_file_path: "#{subentity.details['other']}/#{MANIFESTS_XML}",
        file_path: "#{subentity.details['other']}/#{details['basis_path']}"
      }
      results.add_result(AuditResults::FILE_NOT_IN_MOAB, absent_from_moab_data)
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

  def moab_storage_object
    Moab::StorageObject.new(full_druid, druid_path)
  end

  def druid_path
    @druid_path ||= "#{endpoint.storage_location}/#{DruidTools::Druid.new(full_druid).tree.join('/')}"
  end

  def signature_catalog_entry_path(entry)
    @signature_catalog_entry_paths ||= {}
    @signature_catalog_entry_paths[entry] ||= "#{druid_path}/#{entry.storage_path}"
  end

  def latest_signature_catalog_path
    @latest_signature_catalog_path ||= latest_moab_version.version_pathname.join(MANIFESTS, SIGNATURE_XML).to_s
  end

  # shameless green implementation
  def latest_signature_catalog_entries
    @latest_signature_catalog_entries ||= begin
      if latest_moab_version.signature_catalog
        latest_moab_version.signature_catalog.entries
      else
        absent_from_moab_data = { signature_catalog_path: latest_moab_version.signature_catalog }
        results.add_result(AuditResults::SIGNATURE_CATALOG_NOT_IN_MOAB, absent_from_moab_data)
        []
      end
    end
  # we get here when latest_moab_version.signature_catalog is nil (signatureCatalog.xml does not exist)
  rescue Errno::ENOENT, NoMethodError
    sigcat_path = "#{latest_moab_version.version_pathname}/#{MANIFESTS}/#{SIGNATURE_XML}"
    absent_from_moab_data = { signature_catalog_path: sigcat_path }
    results.add_result(AuditResults::SIGNATURE_CATALOG_NOT_IN_MOAB, absent_from_moab_data)
    []
  end

  def paths_from_signature_catalog
    @paths_from_signature_catalog ||= latest_signature_catalog_entries.map { |entry| signature_catalog_entry_path(entry) }
  end

  def latest_moab_version
    @latest_moab_version ||= moab_storage_object.version_list.last
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
    possible_data_content_dirs = moab_storage_object.versions.map { |sov| sov.file_category_pathname('content') }
    possible_data_metadata_dirs = moab_storage_object.versions.map { |sov| sov.file_category_pathname('metadata') }
    possible_data_dirs = possible_data_content_dirs + possible_data_metadata_dirs
    possible_data_dirs.select(&:exist?).map(&:to_s)
  end

  def calculated_signature(file)
    Moab::FileSignature.new.signature_from_file(Pathname(file))
  end
end
