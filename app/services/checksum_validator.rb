# code for validating Moab checksums
class ChecksumValidator

  attr_reader :checksum_results, :druid, :endpoint

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

  def initialize(druid, endpoint_name)
    @druid = "druid:#{druid}"
    @endpoint = Endpoint.find_by(endpoint_name: endpoint_name)
    @checksum_results = AuditResults.new(druid, nil, endpoint)
  end

  def validate_checksum
    validate_manifest_inventories
    validate_signature_catalog
    checksum_results.add_result(AuditResults::MOAB_CHECKSUM_VALID) if checksum_results.result_array.empty?
    checksum_results.result_array
  end

  def validate_manifest_inventories
    moab_storage_object.version_list.each { |moab_version| validate_manifest_inventory(moab_version) }
    checksum_results.report_results
  end

  def validate_signature_catalog # against data_content_files
    begin
      latest_signature_catalog_entries.each { |entry| validate_signature_catalog_entry(entry) }
    rescue Errno::ENOENT
      checksum_results.add_result(AuditResults::MANIFEST_NOT_IN_MOAB, manifest_file_path: latest_signature_catalog_path)
    rescue Nokogiri::XML::SyntaxError
      checksum_results.add_result(AuditResults::INVALID_MANIFEST, manifest_file_path: latest_signature_catalog_path)
    end
    checksum_results.report_results
  end

  def validate_data_content_files_against_signature_catalog
    data_content_files.each { |file| validate_against_signature_catalog(file) }
    checksum_results.report_results
  end

  private

  # This method adds to the AuditResults object for any errors in checksum validation it encounters.
  def validate_manifest_inventory(moab_version)
    manifest_file_path = "#{moab_version.version_pathname}/#{MANIFESTS}/#{MANIFESTS_XML}"
    begin
      verification_result = moab_version.verify_manifest_inventory
      parse_verification_subentities(verification_result)
    rescue Nokogiri::XML::SyntaxError
      checksum_results.add_result(AuditResults::INVALID_MANIFEST, manifest_file_path: manifest_file_path)
    rescue Errno::ENOENT
      checksum_results.add_result(AuditResults::MANIFEST_NOT_IN_MOAB, manifest_file_path: manifest_file_path)
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
      checksum_results.add_result(AuditResults::MOAB_FILE_CHECKSUM_MISMATCH, mismatch_error_data)
    end
  end

  def add_cv_result_for_additions_in_xml(subentity)
    subentity.details.dig(GROUP_DIFF, MANIFESTS, SUBSETS, ADDED, FILES).each_value do |details|
      absent_from_manifest_data = {
        file_path: "#{subentity.details['other']}/#{details['other_path']}",
        manifest_file_path: "#{subentity.details['other']}/#{MANIFESTS_XML}"
      }
      checksum_results.add_result(AuditResults::FILE_NOT_IN_MANIFEST, absent_from_manifest_data)
    end
  end

  def add_cv_result_for_deletions_in_xml(subentity)
    subentity.details.dig(GROUP_DIFF, MANIFESTS, SUBSETS, DELETED, FILES).each_value do |details|
      absent_from_moab_data = {
        manifest_file_path: "#{subentity.details['other']}/#{MANIFESTS_XML}",
        file_path: "#{subentity.details['other']}/#{details['basis_path']}"
      }
      checksum_results.add_result(AuditResults::FILE_NOT_IN_MOAB, absent_from_moab_data)
    end
  end

  def validate_signature_catalog_entry(entry)
    unless entry.signature.eql?(calculated_signature(signature_catalog_entry_path(entry)))
      mismatch_error_data = { file_path: signature_catalog_entry_path(entry), version: entry.version_id }
      checksum_results.add_result(AuditResults::MOAB_FILE_CHECKSUM_MISMATCH, mismatch_error_data)
    end
  rescue Errno::ENOENT
    absent_from_moab_data = { manifest_file_path: latest_signature_catalog_path,
                              file_path: signature_catalog_entry_path(entry) }
    checksum_results.add_result(AuditResults::FILE_NOT_IN_MOAB, absent_from_moab_data)
  end

  def moab_storage_object
    Moab::StorageObject.new(druid, druid_path)
  end

  def druid_path
    @druid_path ||= "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
  end

  def signature_catalog_entry_path(entry)
    "#{druid_path}/#{entry.storage_path}"
  end

  def latest_signature_catalog_path
    latest_moab_version.version_pathname.join(MANIFESTS, SIGNATURE_XML).to_s
  end

  def latest_signature_catalog_entries
    latest_moab_version.signature_catalog.entries
  end

  def latest_moab_version
    moab_storage_object.version_list.last
  end

  def validate_against_signature_catalog(data_content_file)
    absent_from_manifest_data = { file_path: data_content_file, manifest_file_path: latest_signature_catalog_path }
    file_in_manifest = latest_signature_catalog_entries.any? { |entry| entry.signature.eql?(calculated_signature(data_content_file)) }
    checksum_results.add_result(AuditResults::FILE_NOT_IN_MANIFEST, absent_from_manifest_data) unless file_in_manifest
  end

  # This is more or less ripped from the Find module docs.
  # If the cops don't care about that, I don't care about the cops.
  # rubocop:disable Style/GuardClause, Style/CharacterLiteral
  def data_content_files
    files = []
    existing_data_content_dirs.each do |data_content_dir|
      Find.find(data_content_dir) do |path|
        if FileTest.directory?(path)
          if File.basename(path)[0] == ?.
            Find.prune # Don't look any further into this directory.
          else
            next
          end
        else
          files << path
        end
      end
    end
    files
  end
  # rubocop:enable Style/GuardClause, Style/CharacterLiteral

  def existing_data_content_dirs
    possible_dirs = moab_storage_object.versions.map { |sov| sov.file_category_pathname('content') }
    possible_dirs.select(&:exist?).map(&:to_s)
  end

  def calculated_signature(file)
    Moab::FileSignature.new.signature_from_file(Pathname(file))
  end
end
