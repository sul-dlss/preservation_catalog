# Responsibilities:
# If needed, zip files to zip storage and calculate checksum(s).
# Otherwise, touch the existing main ".zip" file to freshen it in cache.
# Invoke PlexerJob for each zip part.
class ZipmakerJob < DruidVersionJobBase
  queue_as :zipmaker
  delegate :create_zip!, :file_path, :part_keys, to: :zip

  # @param [String] druid
  # @param [Integer] version
  def perform(druid, version)
    if File.exist?(file_path)
      FileUtils.touch(file_path)
    else
      create_zip!
    end
    part_keys.each do |part_key|
      PlexerJob.perform_later(druid, version, part_key, DruidVersionZipPart.new(zip, part_key).metadata)
    end
  end
end
