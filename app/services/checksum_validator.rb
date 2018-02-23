# code for validating Moab checksums
class ChecksumValidator

  attr_reader :handler_results, :druid, :endpoint

  MANIFESTS = 'manifests'.freeze
  MANIFESTS_XML = 'manifestInventory.xml'.freeze

  def initialize(druid, storage_dir)
    @druid = "druid:#{druid}"
    @endpoint = Endpoint.find_by(storage_location: storage_dir)
    @handler_results = AuditResults.new(druid, nil, endpoint)
  end

  def validate_checksum
    # TODO: implement this;  we begin with a placeholder
  end

  # TODO: remove this once refactor parse_verification_subentity
  def validate_manifest_inventories
    storage_object.version_list.each do |storage_object_version|
      validate_manifest_inventory(storage_object_version)
    end
    handler_results.report_results
  end

  private

  def validate_manifest_inventory(storage_object_version)
    manifest_file_path = "#{storage_object_version.version_pathname}/#{MANIFESTS}/#{MANIFESTS_XML}"
    begin
      verification_result = storage_object_version.verify_manifest_inventory
      parse_verification_subentities(verification_result)
    rescue Nokogiri::XML::SyntaxError
      handler_results.add_result(AuditResults::INVALID_MANIFEST, manifest_file_path: manifest_file_path)
    rescue Errno::ENOENT
      handler_results.add_result(AuditResults::MANIFEST_NOT_IN_MOAB, manifest_file_path: manifest_file_path)
    end
  end

  def parse_verification_subentities(result)
    return if result.verified
    result.subentities.each do |subentity|
      parse_verification_subentity(subentity) unless subentity.verified
    end
  end

  def parse_verification_subentity(subentity)
    xml_modified(subentity) unless subentity.details.dig('group_differences', 'manifests', 'subsets', 'modified').nil?

    xml_added(subentity) unless subentity.details.dig('group_differences', 'manifests', 'subsets', 'added').nil?

    xml_deleted(subentity) unless subentity.details.dig('group_differences', 'manifests', 'subsets', 'deleted').nil?
  end

  def xml_modified(subentity)
    subentity.details.dig('group_differences', 'manifests', 'subsets', 'modified', 'files').each_value do |details|
      mismatch_error_message = {
        file_path: "#{subentity.details['other']}/#{details['basis_path']}",
        version: subentity.details['basis']
      }
      handler_results.add_result(AuditResults::MOAB_FILE_CHECKSUM_MISMATCH, mismatch_error_message)
    end
  end

  def xml_added(subentity)
    subentity.details.dig('group_differences', 'manifests', 'subsets', 'added', 'files').each_value do |details|
      absent_from_manifest_message = {
        file_path: "#{subentity.details['other']}/#{details['other_path']}",
        manifest_file_path: "#{subentity.details['other']}/manifestInventory.xml"
      }
      handler_results.add_result(AuditResults::FILE_NOT_IN_MANIFEST, absent_from_manifest_message)
    end
  end

  def xml_deleted(subentity)
    subentity.details.dig('group_differences', 'manifests', 'subsets', 'deleted', 'files').each_value do |details|
      absent_from_moab_message = {
        manifest_file_path: "#{subentity.details['other']}/manifestInventory.xml",
        file_path: "#{subentity.details['other']}/#{details['basis_path']}"
      }
      handler_results.add_result(AuditResults::FILE_NOT_IN_MOAB, absent_from_moab_message)
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

  def storage_object
    Moab::StorageObject.new(@druid, druid_path)
  end

  def signature_catalog_entries
    storage_object.version_list.last.signature_catalog.entries
  end

  def druid_path
    "#{@endpoint.storage_location}/#{DruidTools::Druid.new(@druid).tree.join('/')}"
  end

  def sig_cat_entry_path(e)
    Pathname("#{druid_path}/#{Moab::StorageObject.version_dirname(e.version_id)}/data/#{e.group_id}/#{e.path}")
  end
end
