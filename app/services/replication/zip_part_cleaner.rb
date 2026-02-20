# frozen_string_literal: true

module Replication
  # Deletes all zip part files and their md5 sidecar files from local zip storage
  class ZipPartCleaner
    # @param [ZipPartPathfinder] pathfinder The pathfinder instance for a zip part
    def self.clean!(pathfinder:)
      FileUtils.rm_f(pathfinder.all_file_paths)
    end
  end
end
