# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Replication::MoabVersionFiles do
  subject(:moab_version_files) { described_class.new(root: pathfinder.moab_version_root) }

  let(:pathfinder) do
    Replication::ZipPartPathfinder.new(druid: 'bj102hs9687', version: 1, storage_location:)
  end
  let(:storage_location) { 'spec/fixtures/storage_root01/sdr2objects' }

  describe '#ensure_readable!' do
    let(:v1_moab_files) do
      %w[
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/content/eric-smith-dissertation-augmented.pdf
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/content/eric-smith-dissertation.pdf
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/contentMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/descMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/identityMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/provenanceMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/relationshipMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/rightsMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/technicalMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/data/metadata/versionMetadata.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/manifests/fileInventoryDifference.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/manifests/manifestInventory.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/manifests/signatureCatalog.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/manifests/versionAdditions.xml
        spec/fixtures/storage_root01/sdr2objects/bj/102/hs/9687/bj102hs9687/v0001/manifests/versionInventory.xml
      ]
    end

    it 'calls File.stat on each file in the moab version directory' do
      allow(File).to receive(:stat)
      v1_moab_files.each { |filename| expect(File).to receive(:stat).with(filename) }
      expect { moab_version_files.ensure_readable! }.not_to raise_error
    end

    context 'when an exception is raised' do
      before { allow(File).to receive(:stat).and_raise(Errno::ENOENT) }

      it 'raises Replication::Errors::UnreadableFile' do
        expect { moab_version_files.ensure_readable! }.to raise_error(Replication::Errors::UnreadableFile)
      end
    end
  end

  describe '#moab_version_size' do
    it 'returns the sum of all file sizes in a moab version' do
      expect(moab_version_files.size).to eq(1_928_387)
    end

    context 'when the root is not found' do
      let(:storage_location) { 'spec/fixtures/storage_rootZZZZZZZZZZZZZZ99/sdr2objects' }

      it 'raises Replication::Errors::MoabVersionNotFound' do
        expect { moab_version_files.size }.to raise_error(Replication::Errors::MoabVersionNotFound)
      end
    end
  end
end
