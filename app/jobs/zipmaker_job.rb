require 'open3'
# Responsibilities:
# if needed, zip files to zip storage and calculate checksum
# invoke PlexerJob
class ZipmakerJob < DruidVersionJobBase
  queue_as :zipmaker
  delegate :zip_command, :zip_version, to: :zip

  # @param [String] druid
  # @param [Integer] version
  def perform(druid, version)
    create_zip! unless File.exist?(zip.file_path)
    PlexerJob.perform_later(druid, version, metadata)
  end

  # @todo calculate md5, size of zip for plexer
  def metadata
    { checksum_md5: 'ABC1234', size: '123', zip_cmd: zip_command, zip_version: zip_version }
  end

  def create_zip!
    _output, error, status = Open3.capture3(zip_command)
    raise "zipmaker failure #{error}" unless status.success?
  end
end
