# frozen_string_literal: true

# Confirm checksums for one Moab object on storage (not in database)
# @note Called from ObjectsController, which is typically called by preservation-robots
#   in validate-moab step of preservationIngestWF
# (https://github.com/sul-dlss/workflow-server-rails/blob/main/config/workflows/preservationIngestWF.xml#L18) -
# For explanation as to why, see comment in preservation_robots Robots::SdrRepo::PreservationIngest::ValidateMoab.
class ValidateMoabJob < ApplicationJob
  queue_as :validate_moab

  include UniqueJob

  attr_accessor :druid

  # @param [String] druid of Moab on storage to be checksum validated
  def perform(druid)
    log_failure('Valid druid param required') and return unless DruidTools::Druid.valid?(druid, true)

    @druid = druid.start_with?('druid:') ? druid : "druid:#{druid}"

    start = Time.zone.now
    log_started

    wait_as_needed

    errors = validate
    if errors.empty?
      log_success(Time.zone.now - start)
    else
      log_failure(errors)
    end
  rescue StandardError => e
    log_failure(e.inspect)
  end

  private

  # validate checksums of a Moab
  def validate
    errors = []
    structural_validator = Stanford::StorageObjectValidator.new(moab)
    structural_errors = structural_validator.validation_errors # Returns an array of hashes with error codes => messages
    errors << structural_errors unless structural_errors.empty?

    # reverse because we want to fail fast if there is a problem with the most recent version
    moab.version_list.reverse.each do |version|
      # ensure all files in signatureCatalog.xml exist
      errors << verification_errors(version.verify_signature_catalog)

      # verify_version_storage includes:
      #   verify_manifest_inventory, (which computes and compares v000x/manifest file checksums)
      #   verify_version_inventory, (ensures all files & signatures listed in version inventory exist)
      #   verify_version_additions (which computes v000x/data file checksums and compares them with values in signatureCatalog.xml)
      # we only want to call verify_version_additions for the most recent version, as this is slow for large files
      if moab.current_version_id == version.version_id
        errors << verification_errors(version.verify_version_storage)
      else
        errors << verification_errors(version.verify_manifest_inventory)
        errors << verification_errors(version.verify_version_inventory)
      end
    rescue Errno::ENOENT => e
      errors << e.message # No such file or directory
    rescue Nokogiri::XML::SyntaxError => e
      errors << e
    end

    errors.flatten.compact
  end

  # turn the Moab::VerificationResult into something more easily consumed
  def verification_errors(verification_result, entity = '', errors = [])
    return if verification_result.verified

    new_entity = entity.present? ? "#{entity}: #{verification_result.entity}" : verification_result.entity
    errors << { new_entity => verification_result.details } if verification_result.details

    verification_result.subentities.map do |child_verification_result|
      verification_errors(child_verification_result, new_entity, errors)
    end

    errors
  end

  # @return [Moab::StorageObject] representation of a Moab's storage directory
  def moab
    @moab ||= Moab::StorageServices.find_storage_object(druid)
  end

  def log_started
    workflow_client.update_status(druid: druid,
                                  workflow: 'preservationIngestWF',
                                  process: 'validate-moab',
                                  status: 'started',
                                  note: "Started by preservation_catalog on #{Socket.gethostname}.")
  end

  def log_success(elapsed)
    workflow_client.update_status(druid: druid,
                                  workflow: 'preservationIngestWF',
                                  process: 'validate-moab',
                                  status: 'completed',
                                  elapsed: elapsed,
                                  note: "Completed by preservation_catalog on #{Socket.gethostname}.")
  end

  def log_failure(errors)
    workflow_client.update_error_status(druid: druid,
                                        workflow: 'preservationIngestWF',
                                        process: 'validate-moab',
                                        error_msg: "Problem with Moab validation run on #{Socket.gethostname}: #{errors}")
  end

  def workflow_client
    @workflow_client ||=
      begin
        wf_log = Logger.new('log/workflow_service.log', 'weekly')
        Dor::Workflow::Client.new(url: Settings.workflow_services_url, logger: wf_log)
      end
  end
end
