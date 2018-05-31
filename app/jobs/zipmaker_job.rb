require 'open3'
# Responsibilities:
# locate files
# zip files
# post to zip storage
# invoke PlexerJob
class ZipmakerJob < ApplicationJob
  queue_as :zipmaker

  # @param [String] druid
  # @param [Integer] version
  def perform(druid, version)
    moab_version_path = Moab::StorageServices.object_version_path(druid, version)
    zip_path = DruidVersionZip.new(druid, version).file_path
    unless File.exist?(zip_path)
      ZipmakerJob.create_zip!(zip_path, moab_version_path) if moab_version_path
    end
    PlexerJob.perform_later(druid, version, metadata)
  end

  def metadata
    { checksum_md5: 'ABC1234', size: '123', zip_cmd: 'zip -x ...', zip_version: self.class.zip_version }
  end

  # We presume the system guts do not change underneath a given class instance
  def self.zip_version
    @zip_version ||= fetch_zip_version
  end

  # @return [String] e.g. 'Zip 3.0 (July 5th 2008)' or 'Zip 3.0.1'
  def self.fetch_zip_version
    match = nil
    IO.popen("zip -v") do |io|
      re = zip_version_regexp
      io.find { |line| match = line.match(re) }
    end
    return match[1] if match && match[1].present?
    raise 'No version info matched from `zip -v` ouptut'
  end

  def self.zip_version_regexp
    /This is (Zip \d+(\.\d)+\s*(\(.*\d{4}\))?)/
  end

  # @param [String] path to zip file to be made
  # @param [String] path to druid moab version directory
  # @todo calculate md5 of zip for plexer
  def self.create_zip!(zip_path, moab_version_path)
    _output, error, status = Open3.capture3(zip_command(zip_path, moab_version_path))
    raise "zipmaker failure #{error}" unless status.success?
  end

  # @param [String] path to zip file to be made
  # @param [String] path to druid moab version directory
  # @return [String]
  def self.zip_command(zip_path, moab_version_path)
    "zip -vr0X -s 10g #{zip_path} #{moab_version_path}"
  end
end
