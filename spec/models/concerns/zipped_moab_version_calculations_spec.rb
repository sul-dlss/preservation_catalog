# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ZippedMoabVersionCalculations do
  describe '.with_errors' do
    before do
      create(:zipped_moab_version, status: :ok)
      create(:zipped_moab_version, status: :failed)
      create(:zipped_moab_version, status: :incomplete)
      create(:zipped_moab_version, status: :created)
    end

    it 'returns the count of ZippedMoabVersions with failed status' do
      expect(ZippedMoabVersion.with_errors.count).to eq(1)
    end
  end

  describe '.stuck' do
    before do
      create(:zipped_moab_version, status: :incomplete, status_updated_at: 2.weeks.ago)
      create(:zipped_moab_version, status: :incomplete)
      create(:zipped_moab_version, status: :created, status_updated_at: 8.days.ago)
      create(:zipped_moab_version, status: :ok)
    end

    it 'returns the count of ZippedMoabVersions with incomplete or created statusfor more than a week' do
      expect(ZippedMoabVersion.stuck.count).to eq(2)
    end
  end

  describe '.created_count' do
    before do
      create(:zipped_moab_version, status: :created)
      create(:zipped_moab_version, status: :created)
      create(:zipped_moab_version, status: :ok)
    end

    it 'returns the count of ZippedMoabVersions with status of created' do
      expect(ZippedMoabVersion.created_count).to eq(2)
    end
  end

  describe '.incomplete_count' do
    before do
      create(:zipped_moab_version, status: :incomplete)
      create(:zipped_moab_version, status: :incomplete)
      create(:zipped_moab_version, status: :ok)
    end

    it 'returns the count of ZippedMoabVersions with status of incomplete' do
      expect(ZippedMoabVersion.incomplete_count).to eq(2)
    end
  end

  describe '.missing_count' do
    before do
      create(:preserved_object, current_version: 2)
      # Each ZippedMoabVersion also creates a PreservedObject.
      create_list(:zipped_moab_version, 3)
      # The number of ZipEndpoints is mocked to control the test environment
      allow(ZipEndpoint).to receive(:count).and_return(3)
    end

    it 'returns the count of missing ZippedMoabVersions' do
      # (1 PreservedObject with 2 versions * 3 ZipEndpoints) + (3 PreservedObjects with 1 version * 3 ZipEndpoints) - 3 existing ZippedMoabVersions
      expect(ZippedMoabVersion.missing_count).to eq(12)
    end
  end

  describe '.zipped_moab_versions_by_zip_endpoint' do
    let(:zip_endpoint1) { create(:zip_endpoint) }
    let(:zip_endpoint2) { create(:zip_endpoint) }

    before do
      create_list(:zipped_moab_version, 1, zip_endpoint: zip_endpoint1, status: :ok)
      create_list(:zipped_moab_version, 2, zip_endpoint: zip_endpoint1, status: :failed)
      create_list(:zipped_moab_version, 3, zip_endpoint: zip_endpoint1, status: :created)
      create_list(:zipped_moab_version, 4, zip_endpoint: zip_endpoint1, status: :incomplete)
      create_list(:zipped_moab_version, 5, zip_endpoint: zip_endpoint2, status: :ok)
    end

    it 'returns the aggregation of ZippedMoabVersions by ZipEndpoint and a total aggregation' do
      results, total_result = ZippedMoabVersion.zipped_moab_versions_by_zip_endpoint

      result1 = results.find { |r| r.zip_endpoint == zip_endpoint1 }
      expect(result1.zipped_moab_version_count).to eq(10)
      expect(result1.ok_count).to eq(1)
      expect(result1.failed_count).to eq(2)
      expect(result1.created_count).to eq(3)
      expect(result1.incomplete_count).to eq(4)

      expect(total_result.zipped_moab_version_count).to eq(15)
      expect(total_result.ok_count).to eq(6)
      expect(total_result.failed_count).to eq(2)
      expect(total_result.created_count).to eq(3)
      expect(total_result.incomplete_count).to eq(4)
    end
  end
end
