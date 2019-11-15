# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoabStorageService do
  let(:druid) { 'jj925bx9565' }

  describe '.retrieve_content_file_group' do
    it 'calls Moab::StorageServices.retrieve_file_group for "content"' do
      allow(Moab::StorageServices).to receive(:retrieve_file_group).with('content', druid)
      described_class.retrieve_content_file_group(druid)
      expect(Moab::StorageServices).to have_received(:retrieve_file_group).with('content', druid)
    end
  end
end
