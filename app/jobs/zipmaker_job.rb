require 'open3'
# Responsibilities:
# if needed, zip files to zip storage and calculate checksum
# invoke PlexerJob
class ZipmakerJob < DruidVersionJobBase
  queue_as :zipmaker
  delegate :metadata, :zip_command, to: :zip

  # @param [String] druid
  # @param [Integer] version
  def perform(druid, version)
    create_zip! unless File.exist?(zip.file_path)
    PlexerJob.perform_later(druid, version, metadata)
  end

  def create_zip!
    _output, error, status = Open3.capture3(zip_command)
    raise "zipmaker failure #{error}" unless status.success?
  end
end
