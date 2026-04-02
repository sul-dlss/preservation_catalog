# frozen_string_literal: true

# Job to replicate a PreservedObject to cloud endpoints
class ReplicationJob < ApplicationJob
  queue_as :replication

  limits_concurrency to: 1, key: ->(job) { job.arguments.first }, duration: 3.days, on_conflict: :discard

  def perform(preserved_object)
    preserved_object.populate_zipped_moab_versions!

    ::Replication::AuditService.call(preserved_object: preserved_object)

    (1..preserved_object.current_version).each do |version|
      Replication::ReplicateVersionService.call(preserved_object:, version:)
    end
  end
end
