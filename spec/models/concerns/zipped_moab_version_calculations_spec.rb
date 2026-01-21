# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ZippedMoabVersionCalculations do
  describe '.errors_count' do
    before do
      create(:zipped_moab_version, status: :ok)
      create(:zipped_moab_version, status: :failed)
      create(:zipped_moab_version, status: :incomplete)
      create(:zipped_moab_version, status: :created)
    end

    it 'returns the count of ZippedMoabVersions with failed status' do
      expect(ZippedMoabVersion.errors_count).to eq(1)
    end
  end

  describe '.stuck_count' do
    before do
      create(:zipped_moab_version, status: :incomplete, updated_at: 2.weeks.ago)
      create(:zipped_moab_version, status: :incomplete, updated_at: 3.days.ago)
      create(:zipped_moab_version, status: :created)
      create(:zipped_moab_version, status: :ok)
    end

    it 'returns the count of ZippedMoabVersions with status of validity_unknown for more than a week' do
      expect(ZippedMoabVersion.stuck_count).to eq(2)
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
end
