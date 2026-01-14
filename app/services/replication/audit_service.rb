# frozen_string_literal: true

module Replication
  # Service for auditing a PreservedObject's replication status.
  # The service returns audit results, as well as updating the ZippedMoabVersion statuses.
  class AuditService
    def self.call(...)
      new(...).call
    end

    def initialize(preserved_object:)
      @preserved_object = preserved_object
    end

    # @return [Array<AuditResult>] audit results for each zip endpoint
    def call
      ZipEndpoint.all.to_a.map do |zip_endpoint|
        new_results(zip_endpoint).tap do |results|
          preserved_object.zipped_moab_versions.where(zip_endpoint: zip_endpoint).find_each do |zipped_moab_version|
            Replication::ZippedMoabVersionAuditService.call(zipped_moab_version:, results:)
          end
        end
      end
    end

    private

    attr_reader :preserved_object

    def new_results(zip_endpoint)
      Results.new(druid: preserved_object.druid, moab_storage_root: zip_endpoint, check_name: 'ReplicationAudit')
    end
  end
end
