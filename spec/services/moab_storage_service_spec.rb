# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoabStorageService do
  let(:druid) { 'jj925bx9565' }

  describe '.retrieve_file' do
    it 'calls Stanford::StorageServices.retrieve_file and opens file' do
      allow(Stanford::StorageServices).to receive(:retrieve_file).with('content', 'foo', druid, nil)
      ff = instance_double(File)
      allow(ff).to receive(:read)
      allow(File).to receive(:open).and_return(ff)
      described_class.retrieve_file(druid, 'content', 'foo')
      expect(Stanford::StorageServices).to have_received(:retrieve_file).with('content', 'foo', druid, nil)
    end
  end

  describe '.retrieve_content_file_group' do
    it 'calls Moab::StorageServices.retrieve_file_group for "content"' do
      allow(Moab::StorageServices).to receive(:retrieve_file_group).with('content', druid)
      described_class.retrieve_content_file_group(druid)
      expect(Moab::StorageServices).to have_received(:retrieve_file_group).with('content', druid)
    end
  end
end
