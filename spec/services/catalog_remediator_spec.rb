# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CatalogRemediator do
  let(:fake_audit_results_no_errors) { instance_double(AuditResults, error_results: [], add_result: nil) }
  let(:fake_audit_results_with_errors) { instance_double(AuditResults, error_results: [{ this_is: 'an error' }], add_result: nil) }
  let(:instance) { described_class.new(druid: preserved_object.druid, version: preserved_object.current_version) }
  let!(:preserved_object) { create(:preserved_object) }
  let!(:zip_endpoint) { ZipEndpoint.find_by(endpoint_name: 'aws_s3_west_2') }

  describe '.prune_replication_failures' do
    let(:instance) { instance_double(described_class, prune_replication_failures: nil) }

    before do
      allow(described_class).to receive(:new).and_return(instance)
    end

    it 'calls #prune_replication_failures on a new instance' do
      described_class.prune_replication_failures(druid: preserved_object.druid, version: preserved_object.current_version)
      expect(instance).to have_received(:prune_replication_failures).once
    end
  end

  # NOTE: Yes, we are testing a private method here. There's some logic in the
  #       method that is important enough, given the scope and scale of what
  #       prescat does, to take extra care to test that it works as expected.
  #       Why not make it a public method? There aren't any use cases for making
  #       the method public; there would currently be zero collaborators using
  #       it. Thus, we'll test the private method here.
  describe '#zipped_moab_versions_with_errors' do
    subject(:zipped_moab_versions) { instance.send(:zipped_moab_versions_with_errors).map(&:first) }

    let(:fake_audit_class) { class_double(S3::S3Audit, check_replicated_zipped_moab_version: nil) }

    before do
      # NOTE: We are mocking out the audit-related collaborations of
      #       CatalogRemediator to avoid making e.g. AWS API calls.
      allow(instance).to receive(:endpoint_audit_class_for).and_return(fake_audit_class)
    end

    context 'with zipped moab versions newer than expiry timestamp' do
      let(:zipped_moab_version_new) do
        create(:zipped_moab_version, preserved_object: preserved_object, zip_endpoint: zip_endpoint)
      end

      before do
        allow(instance).to receive(:audit_results_for).with(zipped_moab_version_new).and_return(fake_audit_results_no_errors)
      end

      it 'ignores' do
        expect(zipped_moab_versions).not_to include(zipped_moab_version_new)
      end
    end

    context 'with zipped moab versions lacking errors in audit results' do
      let(:zipped_moab_version_no_errors) do
        create(:zipped_moab_version, preserved_object: preserved_object, zip_endpoint: zip_endpoint, created_at: 3.months.ago).tap do |zmv|
          create(:zip_part, zipped_moab_version: zmv)
        end
      end

      before do
        allow(instance).to receive(:audit_results_for).with(zipped_moab_version_no_errors).and_return(fake_audit_results_no_errors)
      end

      it 'ignores' do
        expect(zipped_moab_versions).not_to include(zipped_moab_version_no_errors)
      end
    end

    context 'with zipped moab versions lacking zip parts' do
      let(:zipped_moab_version_no_parts) do
        create(:zipped_moab_version, preserved_object: preserved_object, zip_endpoint: zip_endpoint, created_at: 3.months.ago)
      end

      before do
        allow(instance).to receive(:audit_results_for).with(zipped_moab_version_no_parts).and_return(fake_audit_results_no_errors)
      end

      it 'includes in audit results' do
        expect(zipped_moab_versions).to include(zipped_moab_version_no_parts)
      end
    end

    context 'with zipped moab versions with errors in audit results' do
      let(:zipped_moab_version_with_errors) do
        create(:zipped_moab_version, preserved_object: preserved_object, zip_endpoint: zip_endpoint, created_at: 3.months.ago).tap do |zmv|
          create(:zip_part, zipped_moab_version: zmv)
        end
      end

      before do
        allow(instance).to receive(:audit_results_for).with(zipped_moab_version_with_errors).and_return(fake_audit_results_with_errors)
      end

      it 'includes in audit results' do
        expect(zipped_moab_versions).to include(zipped_moab_version_with_errors)
      end
    end
  end

  describe '#prune_replication_failures' do
    let(:failures) { instance.prune_replication_failures }

    let(:zipped_moab_version_no_errors) do
      create(:zipped_moab_version, preserved_object: preserved_object, zip_endpoint: zip_endpoint, created_at: 3.months.ago, version: 2).tap do |zmv|
        create(:zip_part, zipped_moab_version: zmv)
      end
    end
    let(:zipped_moab_version_no_parts) do
      create(:zipped_moab_version, preserved_object: preserved_object, zip_endpoint: zip_endpoint, created_at: 3.months.ago, version: 3)
    end
    let(:zipped_moab_version_with_errors) do
      create(:zipped_moab_version, preserved_object: preserved_object, zip_endpoint: zip_endpoint, created_at: 3.months.ago, version: 4).tap do |zmv|
        create(:zip_part, zipped_moab_version: zmv)
      end
    end

    before do
      allow(Rails.logger).to receive(:info)
      allow(instance).to receive(:zipped_moab_versions_with_errors)
        .and_return(
          [
            [zipped_moab_version_no_parts, fake_audit_results_no_errors],
            [zipped_moab_version_with_errors, fake_audit_results_with_errors]
          ]
        )
      allow(ApplicationRecord).to receive(:transaction).and_call_original

      failures
    end

    it 'logs an informational message' do
      expect(Rails.logger).to have_received(:info).twice
    end

    it 'creates a transaction' do
      expect(ApplicationRecord).to have_received(:transaction).at_least(:twice)
    end

    it 'destroys the affected zipped moab versions and related zip parts' do
      expect(zipped_moab_version_no_parts.zip_parts).to be_empty
      expect(zipped_moab_version_no_parts).to be_destroyed
      expect(zipped_moab_version_with_errors.zip_parts).to be_empty
      expect(zipped_moab_version_with_errors).to be_destroyed
    end

    it 'returns an array of zipped moab version versions and endpoint names' do
      expect(failures).to eq([
                               [zipped_moab_version_no_parts.version, zipped_moab_version_no_parts.zip_endpoint.endpoint_name],
                               [zipped_moab_version_with_errors.version, zipped_moab_version_with_errors.zip_endpoint.endpoint_name]
                             ])
    end
  end
end
