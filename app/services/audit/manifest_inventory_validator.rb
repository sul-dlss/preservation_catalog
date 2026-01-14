# frozen_string_literal: true

module Audit
  # Validates files on storage against the manifest inventory
  class ManifestInventoryValidator
    MANIFESTS = 'manifests'
    MANIFESTS_XML = 'manifestInventory.xml'
    MODIFIED = 'modified'
    ADDED = 'added'
    DELETED = 'deleted'
    FILES = 'files'

    def self.validate(moab_version:, checksum_validator:)
      new(moab_version:, checksum_validator:).validate
    end

    def initialize(moab_version:, checksum_validator:)
      @moab_version = moab_version
      @checksum_validator = checksum_validator
    end

    # Adds to the Results object for any errors in checksum validation it encounters.
    def validate
      return if manifest_inventory_verification_result.verified

      manifest_inventory_verification_result.subentities.each do |subentity|
        parse_verification_subentity(subentity) unless subentity.verified
      end
    rescue Nokogiri::XML::SyntaxError
      results.add_result(Results::INVALID_MANIFEST, manifest_file_path: manifest_file_path)
    rescue Errno::ENOENT
      results.add_result(Results::MANIFEST_NOT_IN_MOAB, manifest_file_path: manifest_file_path)
    end

    private

    attr_reader :moab_version, :checksum_validator

    delegate :results, to: :checksum_validator

    def manifest_file_path
      @manifest_file_path ||= "#{moab_version.version_pathname}/#{MANIFESTS}/#{MANIFESTS_XML}"
    end

    def manifest_inventory_verification_result
      @manifest_inventory_verification_result ||= moab_version.verify_manifest_inventory
    end

    # @param [Moab::VerificationResult] subentity
    def parse_verification_subentity(subentity)
      add_result_for_modified_xml(subentity) if subentity.subsets[MODIFIED]
      add_result_for_additions_in_xml(subentity) if subentity.subsets[ADDED]
      add_result_for_deletions_in_xml(subentity) if subentity.subsets[DELETED]
    end

    def add_result_for_modified_xml(subentity)
      subentity.subsets.dig(MODIFIED, FILES).each_value do |details|
        results.add_result(
          Results::MOAB_FILE_CHECKSUM_MISMATCH,
          file_path: "#{subentity.details['other']}/#{details['basis_path']}",
          version: subentity.details['basis']
        )
      end
    end

    def add_result_for_additions_in_xml(subentity)
      subentity.subsets.dig(ADDED, FILES).each_value do |details|
        results.add_result(
          Results::FILE_NOT_IN_MANIFEST,
          file_path: "#{subentity.details['other']}/#{details['other_path']}",
          manifest_file_path: "#{subentity.details['other']}/#{MANIFESTS_XML}"
        )
      end
    end

    def add_result_for_deletions_in_xml(subentity)
      subentity.subsets.dig(DELETED, FILES).each_value do |details|
        results.add_result(
          Results::FILE_NOT_IN_MOAB,
          file_path: "#{subentity.details['other']}/#{details['basis_path']}",
          manifest_file_path: "#{subentity.details['other']}/#{MANIFESTS_XML}"
        )
      end
    end
  end
end
