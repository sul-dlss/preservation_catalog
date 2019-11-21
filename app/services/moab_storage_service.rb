# frozen_string_literal: true

# Responsibility: interactions with Moab storage to support read-only access for ReST API calls
class MoabStorageService
  # @param [String] druid
  # @param [String] category category of desired file ('content', 'metadata', or 'manifest')
  # @param [String] filename name of the file (path relative to base directory)
  # @param [String] version of the file (nil = latest)
  # @return [Pathname] Pathname object containing the full path for the specified file
  # @raise [Moab::ObjectNotFoundException] if file not found
  def self.retrieve_file(druid, category, filename, version=nil)
    raise(ArgumentError, "No filename provided to MoabStorageService.retrieve_file for druid #{druid}") if filename.blank?
    err_msg = "category arg must be 'content', 'metadata', or 'manifest' (MoabStorageService.retrieve_file for druid #{druid})"
    raise(ArgumentError, err_msg) unless ['content', 'metadata', 'manifest'].include?(category)
    file_pathname = Stanford::StorageServices.retrieve_file(category, filename, druid, version)
    File.open(file_pathname).read
  end

  def self.retrieve_content_file_group(druid)
    Moab::StorageServices.retrieve_file_group('content', druid)
  end
end
