# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Audit::ChecksumValidator do
  let(:checksum_validator) { described_class.new(moab_storage_object:, emit_results:) }

  let(:moab_storage_object) { MoabOnStorage.moab(storage_location:, druid:) }
  let(:emit_results) { true }

  let(:result_codes) { checksum_validator.results.map(&:keys).flatten }

  describe '#validate' do
    context 'valid moab' do
      let(:storage_location) { Rails.root.join('spec/fixtures/storage_root01/sdr2objects/') }
      let(:druid) { 'bz514sm9647' }
      let(:expected_result_output) do
        "✅ fixity check passed - validate_checksums - bz514sm9647 - actual location: #{storage_location}; actual version: 3"
      end

      context 'emit_results is false' do
        let(:emit_results) { false }

        it 'does not print anything to stdout' do
          expect { checksum_validator.validate }.not_to output.to_stdout
        end
      end

      it 'does not detect errors' do
        expect { checksum_validator.validate }.to output(/#{Regexp.escape(expected_result_output)}/).to_stdout
        expect(checksum_validator.results.to_s).not_to include('errors')
        expect(result_codes).to be_empty
      end
    end

    context 'invalid_moab' do
      let(:storage_location) { Rails.root.join('spec/fixtures/checksum_root01/sdr2objects/') }
      let(:druid) { 'zz925bx9565' }
      let(:expected_results) do
        [
          { moab_file_checksum_mismatch:
            "checksums or size for #{storage_location}zz/925/bx/9565/zz925bx9565/v0001/manifests/versionAdditions.xml " \
            'version v1 do not match entry in latest signatureCatalog.xml.' },
          { moab_file_checksum_mismatch:
            "checksums or size for #{storage_location}zz/925/bx/9565/zz925bx9565/v0002/manifests/versionInventory.xml " \
            'version v2 do not match entry in latest signatureCatalog.xml.' },
          { file_not_in_signature_catalog:
            "Moab file #{storage_location}zz/925/bx/9565/zz925bx9565/v0001/data/metadata/rightsMetadata 2.xml " \
            "was not found in Moab signature catalog #{storage_location}zz/925/bx/9565/zz925bx9565/v0002/manifests/signatureCatalog.xml" },
          { file_not_in_signature_catalog:
            "Moab file #{storage_location}zz/925/bx/9565/zz925bx9565/v0002/data/metadata/events 2.xml " \
            "was not found in Moab signature catalog #{storage_location}zz/925/bx/9565/zz925bx9565/v0002/manifests/signatureCatalog.xml" },
          { moab_file_checksum_mismatch:
            "checksums or size for #{storage_location}zz/925/bx/9565/zz925bx9565/v0002/data/metadata/descMetadata.xml " \
            'version 2 do not match entry in latest signatureCatalog.xml.' },
          { invalid_moab: 'Invalid Moab, validation errors: ["manifestInventory object_id does not match druid"]' }
        ]
      end
      let(:expected_result_output) do
        (
          ['⚠️ fixity check failed, investigate errors - validate_checksums - zz925bx9565 - ' \
           "actual location: #{storage_location}; actual version: 2"] + expected_results
        ).join("\n* ")
      end

      it 'detects errors' do
        expect { checksum_validator.validate }.to output(/#{Regexp.escape(expected_result_output)}/).to_stdout
        expect(checksum_validator.results.to_s).to include('errors')
        expect(result_codes).to eq(
          %i[moab_file_checksum_mismatch moab_file_checksum_mismatch file_not_in_signature_catalog
             file_not_in_signature_catalog moab_file_checksum_mismatch invalid_moab]
        )
      end
    end
  end
end
