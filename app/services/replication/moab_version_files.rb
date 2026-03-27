# frozen_string_literal: true

module Replication
  # Calculate the total size of all files in a Moab and ensure they are readable
  class MoabVersionFiles
    # @param [String] root The root path for a particular Moab
    def initialize(root:)
      @root = root
    end

    # @raise [Replication::Errors::MoabVersionNotFound] when Moab version root is not found
    # @return [Integer] the sum of all file sizes in the Moab
    def size
      @size ||= files.sum { |f| File.size(f) }
    end

    # Raises an error if any of the files in the moab are not readable, for example, due to
    # Ceph MDS instance for a prescat worker VM thinking that a file is a stray as a result of our
    # particular use of hard-linking in preservation ingest. Allows for a quick directory walk before
    # attempting to create the zip file(s).
    #
    # @see https://github.com/sul-dlss/preservation_catalog/issues/1633
    # @raise [Replication::Errors::UnreadableFile] wraps an underlying file access / readability exception
    # @raise [Replication::Errors::MoabVersionNotFound] when Moab version root is not found
    # @return [NilClass] indicates success
    def ensure_readable!
      files.each { |f| File.stat(f) }

      nil
    rescue StandardError => e # e.g., Errno::EACCES, Errno::EIO, Errno::ENOENT, Errno::ESTALE
      raise Errors::UnreadableFile, "Error reading files (#{e.class}): #{e.message}", e.backtrace
    end

    private

    def files
      raise Errors::MoabVersionNotFound, "Moab version does not exist: #{root}" unless File.exist?(root)

      @files ||= Dir.glob("#{root}/**/*").select { |path| File.file?(path) }
    end

    attr_reader :root
  end
end
