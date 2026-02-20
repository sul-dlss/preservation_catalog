# frozen_string_literal: true

module Replication
  # For replication purposes, we may have to chunk archival objects (zips) of Moab versions into multiple files to avoid
  #   unwieldy file sizes.  This is the model for a single such part.  Many of our archival objects (zips) will only
  #   have one of these, but all will have at least one.
  class ZipPartFile
    attr_reader :filename

    # @note filename locates the file inside zip_storage AND is the s3_key
    # @param [String] filename, e.g. 'ab/123/cd/4567/ab123cd4567.v0001.z03'
    def initialize(filename:)
      @filename = filename
    end

    # @return [String] Path to the local temporary transfer zip (part)
    def file_path
      File.join(Settings.zip_storage, filename)
    end

    # @return [Integer] Zip file size
    def size
      @size ||= FileTest.size(file_path)
    end

    # @return [String] "ab/123/cd/4567/ab123cd4567.v0001.z03.md5"
    def write_md5
      File.write(md5_path, md5)
    end

    # @return [String] The MD5 "7d33a80cb92b081b76aee5feb8bc4569"
    def read_md5
      File.read(md5_path)
    end

    # @return [Boolean] whether the md5 from the md5 sidecar file matches the computed md5
    def md5_match?
      read_md5 == md5.hexdigest
    end

    # @return [String] the filename extension, e.g. '.z03'
    def extname
      File.extname(filename)
    end

    private

    # @return [Digest::MD5] cached md5 object
    def md5
      @md5 ||= Digest::MD5.file(file_path)
    end

    # @return [String] MD5 path
    def md5_path
      "#{file_path}.md5"
    end
  end
end
