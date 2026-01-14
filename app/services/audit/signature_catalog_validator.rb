# frozen_string_literal: true

module Audit
  # Validates files on storage against the signature catalog
  class SignatureCatalogValidator
    MANIFESTS = 'manifests'

    def self.validate(checksum_validator:)
      new(checksum_validator: checksum_validator).validate
    end

    def initialize(checksum_validator:)
      @checksum_validator = checksum_validator
    end

    def validate
      flag_unexpected_data_files
      validate_signature_catalog_listing
    end

    private

    attr_reader :checksum_validator

    delegate :moab_storage_object, :results, :latest_moab_storage_object_version, :object_dir, to: :checksum_validator

    def flag_unexpected_data_files
      data_files.each { |file| validate_against_signature_catalog(file) }
    end

    def data_files
      @data_files ||= [].tap do |files|
        existing_data_dirs.each do |data_dir|
          Find.find(data_dir) { |path| files << path unless FileTest.directory?(path) }
        end
      end
    end

    def existing_data_dirs
      possible_data_content_dirs = moab_storage_object.versions.map { |sov| sov.file_category_pathname('content') }
      possible_data_metadata_dirs = moab_storage_object.versions.map { |sov| sov.file_category_pathname('metadata') }
      possible_data_dirs = possible_data_content_dirs + possible_data_metadata_dirs
      possible_data_dirs.select(&:exist?).map(&:to_s)
    end

    def validate_against_signature_catalog(data_file)
      return if signature_catalog_has_file?(data_file)

      absent_from_signature_catalog_data = { file_path: data_file, signature_catalog_path: latest_signature_catalog_path }

      results.add_result(Results::FILE_NOT_IN_SIGNATURE_CATALOG,
                         absent_from_signature_catalog_data)
    end

    def latest_signature_catalog_path
      @latest_signature_catalog_path ||= latest_moab_storage_object_version.version_pathname.join(MANIFESTS, 'signatureCatalog.xml').to_s
    end

    def paths_from_signature_catalog
      @paths_from_signature_catalog ||= latest_signature_catalog_entries.map { |entry| signature_catalog_entry_path(entry) }
    end

    def signature_catalog_has_file?(file)
      paths_from_signature_catalog.any? { |entry| entry == file }
    end

    # @return [Array<SignatureCatalogEntry>]
    def latest_signature_catalog_entries
      @latest_signature_catalog_entries ||= latest_moab_storage_object_version.signature_catalog.entries
    rescue Errno::ENOENT, NoMethodError # e.g. latest_moab_storage_object_version.signature_catalog is nil (signatureCatalog.xml does not exist)
      results.add_result(Results::SIGNATURE_CATALOG_NOT_IN_MOAB, signature_catalog_path: latest_signature_catalog_path)
      []
    rescue Nokogiri::XML::SyntaxError => e
      results.add_result(Results::INVALID_MANIFEST, manifest_file_path: latest_signature_catalog_path, addl: e.inspect)
      []
    end

    def validate_signature_catalog_listing
      latest_signature_catalog_entries.each { |entry| validate_signature_catalog_entry(entry) }
    rescue Errno::ENOENT
      results.add_result(Results::SIGNATURE_CATALOG_NOT_IN_MOAB, signature_catalog_path: latest_signature_catalog_path)
    rescue Nokogiri::XML::SyntaxError
      results.add_result(Results::INVALID_MANIFEST, manifest_file_path: latest_signature_catalog_path)
    end

    def validate_signature_catalog_entry(entry)
      unless entry.signature.eql?(calculated_signature(signature_catalog_entry_path(entry)))
        mismatch_error_data = { file_path: signature_catalog_entry_path(entry), version: entry.version_id }
        results.add_result(Results::MOAB_FILE_CHECKSUM_MISMATCH, mismatch_error_data)
      end
    rescue Errno::ENOENT
      absent_from_moab_data = { manifest_file_path: latest_signature_catalog_path,
                                file_path: signature_catalog_entry_path(entry) }
      results.add_result(Results::FILE_NOT_IN_MOAB, absent_from_moab_data)
    end

    # @return [String]
    def signature_catalog_entry_path(entry)
      @signature_catalog_entry_paths ||= {}
      @signature_catalog_entry_paths[entry] ||= "#{object_dir}/#{entry.storage_path}"
    end

    def calculated_signature(file)
      Moab::FileSignature.new.signature_from_file(Pathname(file))
    end
  end
end
