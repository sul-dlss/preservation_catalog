# frozen_string_literal: true

module Audit
  # Audit the replication of a single PreservedObject,
  # which may have one or more ZipParts each replicating to multiple configured ZipEndpoints.

  # Delegates to Audit::ReplicationSupport and zip_endpoint.audit_class for actual auditing.
  class Replication
    def self.results(preserved_object)
      new(preserved_object).results
    end

    def initialize(preserved_object)
      @preserved_object = preserved_object
    end

    # Performs the audit and returns true if there are errors.
    def errors?
      results.any? { |audit_results| audit_results.error_results.any? }
    end

    # Performs the audit and returns the results.
    # @return [Array<AuditResult>] audit results for each zip endpoint
    def results
      @results ||= begin
        audit_results_list = zip_endpoints.map do |zip_endpoint|
          result(zip_endpoint)
        end
        preserved_object.update(last_archive_audit: Time.current)
        audit_results_list
      end
    end

    private

    attr_reader :preserved_object

    def zip_endpoints
      ZipEndpoint
        .includes(:zipped_moab_versions)
        .where(zipped_moab_versions: { preserved_object: preserved_object })
    end

    def result(zip_endpoint)
      audit_results = new_audit_results(zip_endpoint)
      preserved_object.zipped_moab_versions.where(zip_endpoint: zip_endpoint).each do |zipped_moab_version|
        next unless Audit::ReplicationSupport.check_child_zip_part_attributes(zipped_moab_version, audit_results)
        zip_endpoint.audit_class.check_replicated_zipped_moab_version(zipped_moab_version, audit_results)
      end
      audit_results
    end

    def new_audit_results(zip_endpoint)
      Audit::Results.new(druid: preserved_object.druid, moab_storage_root: zip_endpoint, check_name: 'PartReplicationAuditJob')
    end
  end
end
