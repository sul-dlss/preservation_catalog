# code for validating Moab checksums
class ChecksumValidator
  def initialize(druid, endpoint, algorithm)
    @druid = druid
    @endpoint = endpoint
    @algorithm = algorithm
  end

  def validate_checksum
    # TODO: implement this;  we begin with a placeholder
  end

  # exploring a solution for #521 --
  # for each manInv file, compare checksums
  def validate_manifest_inventories
    results = []
    storage_object.version_list.each do |storage_object_version|
      results << storage_object_version.verify_manifest_inventory
    end
    results.map(&:verified)
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
