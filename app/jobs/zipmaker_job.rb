# Responsibilities:
# If needed, zip files to zip storage and calculate checksum(s).
# Otherwise, touch the existing main ".zip" file to freshen it in cache.
# Invoke PlexerJob for each zip part.
class ZipmakerJob < DruidVersionJobBase
  queue_as :zipmaker
  delegate :metadata_for_part, :create_zip!, :file_path, :part_names, to: :zip

  # @param [String] druid
  # @param [Integer] version
  def perform(druid, version)
    if File.exist?(file_path)
      FileUtils.touch(file_path)
    else
      create_zip!
    end
    part_names.each do |part|
      file = File.basename(part)
      PlexerJob.perform_later(druid, version, file, metadata_for_part(part))
    end
  end
end
