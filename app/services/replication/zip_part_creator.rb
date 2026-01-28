# frozen_string_literal: true

require 'open3'

module Replication
  # Creates a zip of Druid-Version content.
  # Changes directory so that the storage root (and druid tree) are not part of
  # the archival directory structure, just the object, e.g. starting at 'ab123cd4567/...' directory,
  # not 'ab/123/cd/4567/ab123cd4567/...'
  class ZipPartCreator
    def self.create!(...)
      new(...).create!
    end

    # the size used with "zip -s" to break up the zip into parts
    ZIP_SPLIT_SIZE = '10g'

    # @param [ZipPartPathfinder] pathfinder The pathfinder instance for a zip part
    def initialize(pathfinder:)
      @pathfinder = pathfinder
    end

    # @raise [Replication::Errors::UnreadableFile] wraps an underlying file access / readability exception
    # @raise [Replication::Errors::MoabVersionNotFound] when Moab version root is not found
    # @raise [Replication::Errors::ZipmakerFailure] when zip command fails
    def create! # rubocop:disable Metrics/AbcSize
      moab_version_files.ensure_readable!

      # Ensure the directory the zip will live in exists
      Pathname.new(pathfinder.file_path).tap { |pn| pn.dirname.mkpath }

      combined, status = Open3.capture2e(zip_command, chdir: work_dir.to_s)
      raise Errors::ZipmakerFailure, "zipmaker failure #{combined}" unless status.success?

      # This assumes that the zip file will be at least as large as the Moab version being zipped. Why? Because
      # we don't enable compression (see zip_command). Why no compression? We thought it might make extraction
      # from zips more reliable in the distant future. For further explanation, see
      # https://github.com/sul-dlss/preservation_catalog/wiki/Zip-Creation
      if total_part_size <= moab_version_files.size
        raise Errors::ZipmakerFailure,
              "zip size (#{total_part_size}) is smaller than the moab version size (#{moab_version_files.size})!" \
              "zipmaker failure #{combined}"
      end

      pathfinder.zip_keys.each do |zip_key|
        Replication::ZipPartFile.new(filename: zip_key).write_md5
      end
    rescue StandardError
      ZipPartCleaner.clean!(pathfinder:)

      raise
    end

    private

    attr_reader :pathfinder

    def moab_version_files
      @moab_version_files ||= MoabVersionFiles.new(root: pathfinder.moab_version_root)
    end

    def total_part_size
      @total_part_size ||= pathfinder.zip_paths.sum { |zip_path| File.size(zip_path) }
    end

    # Presumes execution just "above" the druid dir in the druid tree, i.e. if the Moab is:
    #   /storage_trunk_01/bj/102/hs/9687/bj102hs9687/v0003/...
    # This command should execute from:
    #   /storage_trunk_01/bj/102/hs/9687/
    # @see #work_dir
    # @return [String] shell command to create this zip
    def zip_command
      "zip -r0X -s #{ZIP_SPLIT_SIZE} #{pathfinder.file_path} #{pathfinder.druid.id}/#{pathfinder.version_string}"
    end

    # @return [Pathname] The proper directory in which to execute zip_command
    def work_dir
      Pathname.new(pathfinder.moab_version_root).parent.parent
    end
  end
end
