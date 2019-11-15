# frozen_string_literal: true

# Responsibility: interactions with Moab storage to support read-only access for ReST API calls
class MoabStorageService
  def self.retrieve_content_file_group(druid)
    Moab::StorageServices.retrieve_file_group('content', druid)
  end
end
