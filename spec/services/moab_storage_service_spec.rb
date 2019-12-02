# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MoabStorageService do
  let(:druid) { 'jj925bx9565' }

  describe '.filepath' do
    let(:category) { '' }
    let(:fname) { 'foo' }
    let(:version) { nil }
    let(:file_path) { 'my/file/path.txt' }

    it 'calls Stanford::StorageServices.retrieve_file' do
      allow(Stanford::StorageServices).to receive(:retrieve_file).with('content', fname, druid, version).and_return(file_path)
      expect(described_class.filepath(druid, 'content', fname)).to eq file_path
      expect(Stanford::StorageServices).to have_received(:retrieve_file).with('content', fname, druid, version)
    end

    context 'when file is not in Moab' do
      it 'passes along error raised by moab-versioning gem' do
        emsg = 'my error'
        allow(Stanford::StorageServices).to receive(:retrieve_file).with('content', 'foobar', druid, version).and_raise(Moab::MoabRuntimeError, emsg)
        expect { described_class.filepath(druid, 'content', 'foobar') }.to raise_error(Moab::MoabRuntimeError, emsg)
      end
    end

    describe 'category param:' do
      let(:err_msg) { "category arg must be 'content', 'metadata', or 'manifest' (MoabStorageService.filepath for druid jj925bx9565)" }

      before do
        allow(Stanford::StorageServices).to receive(:retrieve_file).with(category, fname, druid, version).and_return(file_path)
      end

      context 'when manifest' do
        let(:category) { 'manifest' }

        it 'returns the requested filepath' do
          expect(described_class.filepath(druid, category, fname)).to eq file_path
        end
      end

      context 'when metadata' do
        let(:category) { 'metadata' }

        it 'returns the requested filepath' do
          expect(described_class.filepath(druid, category, fname)).to eq file_path
        end
      end

      context 'when content' do
        let(:category) { 'content' }

        it 'returns the requested filepath' do
          expect(described_class.filepath(druid, category, fname)).to eq file_path
        end
      end

      context 'when unrecognized value' do
        let(:category) { 'unrecognized' }

        it 'raises ArgumentError' do
          expect { described_class.filepath(druid, category, fname) }.to raise_error(ArgumentError, err_msg)
        end
      end

      context 'when missing' do
        it 'raises ArgumentError' do
          expect { described_class.filepath(druid, nil, fname) }.to raise_error(ArgumentError, err_msg)
        end
      end
    end

    describe 'filename param' do
      before do
        allow(Stanford::StorageServices).to receive(:retrieve_file).with(category, fname, druid, version).and_return(file_path)
      end

      context 'when missing' do
        let(:err_msg) { "No filename provided to MoabStorageService.filepath for druid jj925bx9565" }

        it 'raises ArgumentError' do
          expect { described_class.filepath(druid, 'metadata', nil) }.to raise_error(ArgumentError, err_msg)
        end
      end
    end

    describe 'version param' do
      let(:exp_pathname) do
        Pathname.new('spec/fixtures/storage_root01/sdr2objects/jj/925/bx/9565/jj925bx9565/v0002/manifests/manifestInventory.xml')
      end

      context 'when specified correctly' do
        let(:exp_pathname) do
          Pathname.new('spec/fixtures/storage_root01/sdr2objects/jj/925/bx/9565/jj925bx9565/v0001/manifests/manifestInventory.xml')
        end

        it 'returns the requested filepath' do
          expect(described_class.filepath(druid, 'manifest', 'manifestInventory.xml', 1)).to eq exp_pathname
        end
      end

      context 'when not a positive integer value' do
        it 'raises Moab::MoabRuntimeError' do
          err_msg = 'Version ID v3 does not exist'
          expect { described_class.filepath(druid, 'metadata', fname, 'v3') }.to raise_error(Moab::MoabRuntimeError, err_msg)
        end
      end

      context 'when too high a version' do
        it 'raises Moab::MoabRuntimeError' do
          err_msg = 'Version ID 666 does not exist'
          expect { described_class.filepath(druid, 'metadata', fname, 666) }.to raise_error(Moab::MoabRuntimeError, err_msg)
        end
      end

      context 'when missing' do
        it 'returns the most recent version' do
          expect(described_class.filepath(druid, 'manifest', 'manifestInventory.xml')).to eq exp_pathname
        end
      end
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
