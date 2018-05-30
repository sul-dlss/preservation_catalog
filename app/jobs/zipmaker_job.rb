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
    PlexerJob.perform_later(druid, version)
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
