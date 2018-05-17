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
    binary_path = Moab::StorageServices.object_version_path(druid, version)
    zip_path = DruidVersionZip.new(druid, version).file_path
    unless File.exist?(zip_path)
      ZipmakerJob.zip_binary(zip_path, binary_path) if binary_path
    end
    PlexerJob.perform_later(druid, version)
  end

  # @param [String] path to druid version zip
  # @param [String] path to druid version
  # @todo calculate md5 of zip for plexer
  def self.zip_binary(zip_path, binary_path)
    _output, error, status = Open3.capture3(zip_command(zip_path, binary_path))
    raise "zipmaker failure #{error}" unless status.success?
  end

  # @param [String] path to druid version zip
  # @param [String] path to druid version
  # @return [String]
  def self.zip_command(zip_path, binary_path)
    "zip -vr0X -s 10g #{zip_path} #{binary_path}"
  end
end
