# frozen_string_literal: true

# Confirm checksums for one Moab object on disk (not in database)
class ValidateMoabJob < ApplicationJob
  queue_as :validate_moab

  before_enqueue do |job|
    err_msg = 'Druid param required, with druid prefix and without alpha chars aeilou'
    raise ArgumentError, err_msg unless DruidTools::Druid.valid?(job.arguments.first, true)
  end

  attr :druid

  # @param [String] druid of Moab on disk to be checksum validated
  def perform(druid)
    @druid = druid
    start = Time.zone.now
    log_started

    # TODO: what if we lose connectivity while it's running in resque
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
  # rubocop:disable Metrics/AbcSize
  def validate
    errors = []
    structural_validator = Stanford::StorageObjectValidator.new(moab)
    structural_errors = structural_validator.validation_errors # Returns an array of hashes with error codes => messages
    errors << structural_errors unless structural_errors.empty?

    moab.version_list.each do |version|
      # ensure all files in signatureCatalog.xml exist
      errors << verification_errors(version.verify_signature_catalog)

      # verify_version_storage includes:
      #   verify_manifest_inventory, (which computes and compares v000x/manifest file checksums)
      #   verify_version_inventory,
      #   verify_version_additions (which computes v000x/data file checksums and compares them with values in signatureCatalog.xml)
      errors << verification_errors(version.verify_version_storage)
    rescue Errno::ENOENT => e
      errors << e.message # No such file or directory
    rescue Nokogiri::XML::SyntaxError => e
      errors << e
    end

    errors.flatten.compact
  end
  # rubocop:enable Metrics/AbcSize

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
    @moab ||= begin
      bare_druid = druid.split(':').last
      Moab::StorageServices.find_storage_object(bare_druid)
    end
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
