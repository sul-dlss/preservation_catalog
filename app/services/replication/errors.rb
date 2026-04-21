# frozen_string_literal: true

module Replication
  # Replication-related exceptions
  module Errors
    # Raised when a Moab version directory is not found
    class MoabVersionDirectoryNotFound < RuntimeError; end

    # Raised when a file is unreadable due to access restrictions, stale
    # handles, I/O snafus, and so on
    class UnreadableFile < RuntimeError; end

    # Raised when the zip command fails
    class ZipmakerFailure < RuntimeError; end
  end
end
