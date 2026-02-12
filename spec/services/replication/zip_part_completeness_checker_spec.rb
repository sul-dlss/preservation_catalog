# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Replication::ZipPartCompletenessChecker do
  subject(:checker) { described_class.new(pathfinder:) }

  let(:pathfinder) do
    Replication::ZipPartPathfinder.new(
      druid: 'bj102hs9687',
      version: 3,
      storage_location: 'spec/fixtures/storage_root01/sdr2objects'
    )
  end

  describe '.complete?' do
    let(:instance) { instance_double(described_class, complete?: nil) }

    before do
      allow(described_class).to receive(:new).and_return(instance)
    end

    it 'calls #complete? on a new instance' do
      described_class.complete?(pathfinder:)
      expect(instance).to have_received(:complete?).once
    end
  end

  describe '#complete?' do
    after { FileUtils.rm_rf('/tmp/bj') } # cleanup

    context 'when zip does not exist' do
      it 'returns false' do
        expect(checker).not_to be_complete
      end
    end

    context 'when zip is complete' do
      before do
        Replication::ZipPartCreator.create!(pathfinder:)
      end

      it 'returns true' do
        expect(checker).to be_complete
      end
    end

    context 'when there is a zip file with no md5 sidecar' do
      before do
        Replication::ZipPartCreator.create!(pathfinder:)
        File.delete("#{pathfinder.file_path}.md5")
      end

      it 'returns false' do
        expect(checker).not_to be_complete
      end
    end

    context 'when there is a md5 sidecar with no zip file' do
      before do
        Replication::ZipPartCreator.create!(pathfinder:)
        File.delete(pathfinder.file_path)
      end

      it 'returns false' do
        expect(checker).not_to be_complete
      end
    end

    context 'when the md5 sidecar does not match the zip file' do
      before do
        Replication::ZipPartCreator.create!(pathfinder:)
        File.write("#{pathfinder.file_path}.md5", 'notthecorrectmd5value')
      end

      it 'returns false' do
        expect(checker).not_to be_complete
      end
    end
  end
end
