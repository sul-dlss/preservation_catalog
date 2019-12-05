# frozen_string_literal: true

# Responsibility: interactions with Moab storage to support read-only access for ReST API calls
class MoabStorageService
  # @return an XML file representing [Moab::FileInventoryDifference]
  #   from comparison of passed contentMetadata.xml with latest (or specified) version in Moab,
  #   for all files (default) or a specified subset (shelve|preserve|publish)
  # @raise ArgumentError or Moab::MoabRuntimeError as appropriate
  # @param [String] druid
  # @param [String] contentMetadata.xml to be compared against a version already in the Moab
  # @param [String] subset (default: 'all') which subset of files to compare (all|shelve|preserve|publish)
  # @param [Integer, nil] version of Moab to be compared against (defaults to latest version)
  def self.content_diff(druid, content_md, subset='all', version=nil)
    raise(ArgumentError, "No contentMetadata provided to MoabStorageService.content_diff for druid #{druid}") if content_md.blank?
    err_msg = "subset arg must be 'all', 'shelve', 'preserve', or 'publish' (MoabStorageService.content_diff for druid #{druid})"
    raise(ArgumentError, err_msg) unless ['all', 'shelve', 'preserve', 'publish'].include?(subset)
    Stanford::StorageServices.compare_cm_to_version(content_md, druid, subset, version)
  end

  # @return [Pathname] Pathname object containing the full path for the specified file
  # @raise ArgumentError or Moab::MoabRuntimeError as appropriate
  # @param [String] druid
  # @param [String] category category of desired file ('content', 'metadata', or 'manifest')
  # @param [String] filename name of the file (path relative to base directory)
  # @param [Integer, nil] version of the file (nil = latest)
  def self.filepath(druid, category, filename, version=nil)
    raise(ArgumentError, "No filename provided to MoabStorageService.filepath for druid #{druid}") if filename.blank?
    err_msg = "category arg must be 'content', 'metadata', or 'manifest' (MoabStorageService.filepath for druid #{druid})"
    raise(ArgumentError, err_msg) unless ['content', 'metadata', 'manifest'].include?(category)
    Stanford::StorageServices.retrieve_file(category, filename, druid, version)
  end

  def self.retrieve_content_file_group(druid)
    Moab::StorageServices.retrieve_file_group('content', druid)
  end
end
