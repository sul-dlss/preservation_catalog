# code for validating Moab checksums
class ChecksumValidator

  attr_reader :checksum_results, :druid, :endpoint

  MANIFESTS = 'manifests'.freeze
  MANIFESTS_XML = 'manifestInventory.xml'.freeze
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
    # TODO: implement this;  we begin with a placeholder
  end

  def validate_manifest_inventories
    moab_storage_object.version_list.each do |moab_version|
      validate_manifest_inventory(moab_version)
    end
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
      mismatch_error_results = {
        file_path: "#{subentity.details['other']}/#{details['basis_path']}",
        version: subentity.details['basis']
      }
      checksum_results.add_result(AuditResults::MOAB_FILE_CHECKSUM_MISMATCH, mismatch_error_results)
    end
  end

  def add_cv_result_for_additions_in_xml(subentity)
    subentity.details.dig(GROUP_DIFF, MANIFESTS, SUBSETS, ADDED, FILES).each_value do |details|
      absent_from_manifest_results = {
        file_path: "#{subentity.details['other']}/#{details['other_path']}",
        manifest_file_path: "#{subentity.details['other']}/#{MANIFESTS_XML}"
      }
      checksum_results.add_result(AuditResults::FILE_NOT_IN_MANIFEST, absent_from_manifest_results)
    end
  end

  def add_cv_result_for_deletions_in_xml(subentity)
    subentity.details.dig(GROUP_DIFF, MANIFESTS, SUBSETS, DELETED, FILES).each_value do |details|
      absent_from_moab_results = {
        manifest_file_path: "#{subentity.details['other']}/#{MANIFESTS_XML}",
        file_path: "#{subentity.details['other']}/#{details['basis_path']}"
      }
      checksum_results.add_result(AuditResults::FILE_NOT_IN_MOAB, absent_from_moab_results)
    end
  end

  # exploring a solution for #522
  # for latest sigcat, compare checksums
  def validate_signature_catalog
    results = []
    signature_catalog_entries.each do |sig_cat_entry|
      calculated_signature = Moab::FileSignature.new.signature_from_file(sig_cat_entry_path(sig_cat_entry))
      results << sig_cat_entry.signature.eql?(calculated_signature)
    end
    results
  end

  def moab_storage_object
    Moab::StorageObject.new(druid, druid_path)
  end

  def signature_catalog_entries
    moab_storage_object.version_list.last.signature_catalog.entries
  end

  def druid_path
    "#{endpoint.storage_location}/#{DruidTools::Druid.new(druid).tree.join('/')}"
  end

  def sig_cat_entry_path(e)
    Pathname("#{druid_path}/#{Moab::StorageObject.version_dirname(e.version_id)}/data/#{e.group_id}/#{e.path}")
  end
end
