# frozen_string_literal: true

# Responsibility: interactions with Moab storage to support read-only access for ReST API calls
class MoabStorageService
  # @return [Pathname] Pathname object containing the full path for the specified file
  #  raises ArgumentError or Moab::MoabRuntimeError as appropriate
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
