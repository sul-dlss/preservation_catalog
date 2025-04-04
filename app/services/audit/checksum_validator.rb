# frozen_string_literal: true

module Audit
  # Service for validating Moab checksums in a directory. This class's primary collaborator
  # is Audit::ChecksumValidationService, which depends on Audit::ChecksumValidator to
  # validate manifest inventories on disk and update the passed-in `results` object. It is
  # also invoked by the `prescat:audit:validate_uncataloged` rake task which expects the
  # class to emit validation results and errors to STDOUT.
  class ChecksumValidator
    attr_reader :moab_storage_object

    def initialize(moab_storage_object:, results: nil, logger: nil, emit_results: false)
      @moab_storage_object = moab_storage_object
      @results = results
      @logger = logger
      @emit_results = emit_results
    end

    def validate
      validate_manifest_inventories
      validate_signature_catalog
    end

    def validate_manifest_inventories
      # This will populate the results object
      moab_storage_object.version_list.each { |moab_version| ManifestInventoryValidator.validate(moab_version:, checksum_validator: self) }

      print_results!
    end

    def validate_signature_catalog
      SignatureCatalogValidator.validate(checksum_validator: self)
    end

    # @return [Moab::StorageObjectVersion]
    def latest_moab_storage_object_version
      @latest_moab_storage_object_version ||= moab_storage_object.version_list.last
    end

    # @return [Boolean] false if the moab exists, true otherwise
    def moab_on_storage_absent?
      !File.exist?(object_dir) || latest_moab_storage_object_version.nil?
    end

    def print_results!
      return unless emit_results?

      # NOTE: `MoabOnStorageValidator#moab_validation_errors` does not only
      #       return errors; it bears primary responsibility for *running* the
      #       validation.
      moab_on_storage_validator.moab_validation_errors

      logger.info(results.results_as_string)
    end

    def emit_results?
      @emit_results
    end

    def moab_on_storage_validator
      @moab_on_storage_validator ||= MoabOnStorage::Validator.new(moab: moab_storage_object, audit_results: results)
    end

    def object_dir
      @object_dir ||= moab_storage_object.object_pathname.to_s
    end

    def druid
      @druid ||= moab_storage_object.digital_object_id
    end

    def results
      @results ||= Audit::Results.new(druid:, moab_storage_root: storage_location, actual_version: moab_storage_object.current_version_id,
                                      check_name: 'validate_checksums')
    end

    def storage_location
      @storage_location ||= moab_storage_object.object_pathname.to_s.delete_suffix(
        DruidTools::Druid.new(druid, moab_storage_object.storage_root).path
      )
    end

    def logger
      @logger ||= Logger.new($stdout)
    end
  end
end
