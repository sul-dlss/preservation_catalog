# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Audit::ChecksumValidator do
  let(:checksum_validator) { described_class.new(moab_storage_object:, emit_results:) }

  let(:moab_storage_object) { MoabOnStorage.moab(storage_location:, druid:) }
  let(:emit_results) { true }

  describe '#validate' do
    context 'valid moab' do
      let(:storage_location) { Rails.root.join('spec/fixtures/storage_root01/sdr2objects/') }
      let(:druid) { 'bj102hs9687' }
      let(:expected_result_string) do
        "validate_checksums (actual location: #{storage_location}; actual version: 3)"
      end

      context 'emit_results is false' do
        let(:emit_results) { false }

        it 'does not print anything to stdout' do
          expect { checksum_validator.validate }.not_to output.to_stdout
        end
      end

      it 'does not detect errors' do
        expect { checksum_validator.validate }.to output(/#{Regexp.escape(expected_result_string)}/).to_stdout
        expect(checksum_validator.results.results_as_string).not_to include('errors')
        expect(checksum_validator.results.results_as_string).to include(expected_result_string)
      end
    end

    context 'invalid_moab' do
      let(:storage_location) { Rails.root.join('spec/fixtures/checksum_root01/sdr2objects/') }
      let(:druid) { 'zz925bx9565' }
      let(:expected_result_string) do
        "validate_checksums (actual location: #{storage_location}; actual version: 2) " \
          "checksums or size for #{storage_location}zz/925/bx/9565/zz925bx9565/v0001/manifests/versionAdditions.xml version v1 do not " \
          'match entry in latest signatureCatalog.xml. ' \
          "&& checksums or size for #{storage_location}zz/925/bx/9565/zz925bx9565/v0002/manifests/versionInventory.xml version v2 do not " \
          'match entry in latest signatureCatalog.xml. ' \
          '&& Invalid Moab, validation errors: ["manifestInventory object_id does not match druid"]'
      end

      it 'detects errors' do
        expect { checksum_validator.validate }.to output(/#{Regexp.escape(expected_result_string)}/).to_stdout
        expect(checksum_validator.results.results_as_string).to include('errors')
        expect(checksum_validator.results.results_as_string).to include(expected_result_string)
      end
    end
  end
end
