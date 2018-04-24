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
    PlexerJob.perform_later(druid, version)
  end
end
