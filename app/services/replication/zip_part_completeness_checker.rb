# frozen_string_literal: true

module Replication
  # Checks if zip part files in local zip storage are complete and consistent
  class ZipPartCompletenessChecker
    def self.complete?(...)
      new(...).complete?
    end

    # @param [ZipPartPathfinder] pathfinder The pathfinder instance for a zip part
    def initialize(pathfinder:)
      @pathfinder = pathfinder
    end

    # @return [Boolean] true if there is a match between the zip part files and their md5 sidecar files
    def complete?
      # There is at least one part file
      return false if pathfinder.zip_paths.empty?

      # The set of md5 sidecar files matches the set of part files
      return false unless pathfinder.zip_keys_match_sidecars?

      # This assumes that the zip file will be at least as large as the Moab
      # version being zipped. Why? Because we don't enable compression (see
      # zip_command). Why no compression? We thought it might make extraction
      # from zips more reliable in the distant future. For further explanation,
      # see https://github.com/sul-dlss/preservation_catalog/wiki/Zip-Creation
      return false if total_part_size <= moab_version_files.size

      # Check each md5 sidecar file against the zip part file
      # @return [Boolean] do all zip file checksums match their md5 sidecar value?
      pathfinder.zip_keys.all? { |zip_key| ZipPartFile.new(filename: zip_key).md5_match? }
    end

    private

    attr_reader :pathfinder

    def total_part_size
      @total_part_size ||= pathfinder.zip_paths.sum { |zip_path| File.size(zip_path) }
    end

    def moab_version_files
      @moab_version_files ||= MoabVersionFiles.new(moab_version_root: pathfinder.moab_version_root)
    end
  end
end
