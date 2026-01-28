# frozen_string_literal: true

module Replication
  # Calculate the total size of all files in a Moab and ensure they are readable
  class MoabVersionFiles
    # @param [String] moab_version_root The path for a particular Moab version directory
    def initialize(moab_version_root:)
      @moab_version_root = moab_version_root
    end

    # @raise [Replication::Errors::MoabVersionDirectoryNotFound] when Moab version directory is not found
    # @return [Integer] the sum of all file sizes in the Moab
    def size
      @size ||= files.sum { |f| File.size(f) }
    end

    # Raises an error if any of the files in the Moab are not readable, due to,
    # e.g.: network problems causing instability in the connection between the
    # VM and the Moab storage roots (which mount a large pool of networked
    # storage that presents as POSIX mounts); load on the storage pool system
    # causing lag in content availability; etc. Allows for a quick directory
    # walk before attempting to create the zip file(s).
    #
    # @see https://github.com/sul-dlss/preservation_catalog/issues/1633
    # @raise [Replication::Errors::UnreadableFile] wraps an underlying file access / readability exception
    # @raise [Replication::Errors::MoabVersionDirectoryNotFound] when Moab version directory is not found
    # @return [NilClass] indicates success
    def ensure_readable!
      files.each { |f| File.stat(f) }

      nil
    rescue StandardError => e # e.g., Errno::EACCES, Errno::EIO, Errno::ENOENT, Errno::ESTALE
      raise Errors::UnreadableFile, "Error reading files (#{e.class}): #{e.message}", e.backtrace
    end

    private

    def files
      raise Errors::MoabVersionDirectoryNotFound, "Moab version directory does not exist: #{moab_version_root}" unless File.exist?(moab_version_root)

      @files ||= Dir.glob("#{moab_version_root}/**/*").select { |path| File.file?(path) }
    end

    attr_reader :moab_version_root
  end
end
