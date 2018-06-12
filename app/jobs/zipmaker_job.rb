# Responsibilities:
# if needed, zip files to zip storage and calculate checksum
# invoke PlexerJob
class ZipmakerJob < DruidVersionJobBase
  queue_as :zipmaker
  delegate :metadata, :create_zip!, :file_path, to: :zip

  # @param [String] druid
  # @param [Integer] version
  def perform(druid, version)
    if File.exist?(file_path)
      FileUtils.touch(file_path)
    else
      create_zip!
    end
    PlexerJob.perform_later(druid, version, metadata)
  end
end
