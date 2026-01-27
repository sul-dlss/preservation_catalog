# frozen_string_literal: true

require 'rails_helper'

describe Replication::DruidVersionZipPart do
  let(:dvz) { Replication::DruidVersionZip.new(druid, version) }
  let(:part) { described_class.new(dvz, 'bj/102/hs/9687/bj102hs9687.v0001.z02') }
  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }
  let(:md5_path) { '/tmp/bj/102/hs/9687/bj102hs9687.v0001.z02.md5' }

  describe '#file_path' do
    it 'returns a full path' do
      expect(part.file_path).to eq '/tmp/bj/102/hs/9687/bj102hs9687.v0001.z02'
    end
  end

  describe '#md5_path' do
    it 'returns the md5 path' do
      expect(part.send(:md5_path)).to eq md5_path
    end
  end

  describe '#write_md5' do
    let(:md5_path) { 'some/file/path/md5' }
    let(:md5) { 'fakemd5' }

    before do
      allow(part).to receive_messages(md5: md5, md5_path: md5_path)
    end

    it 'writes the md5 to the md5_path' do
      expect(File).to receive(:write).with(md5_path, md5)
      part.write_md5
    end
  end

  describe '#read_md5' do
    it 'reads the md5' do
      expect(IO).to receive(:read).with(md5_path)
      part.read_md5
    end
  end

  context 'MD5 checksums and size' do
    let(:part) { described_class.new(dvz, 'bj/102/hs/9687/bj102hs9687.v0001.zip') }

    before do
      allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
    end

    describe '#md5' do
      it 'returns Digest::MD5 object' do
        expect(part.send(:md5).to_s).to eq '4f98f59e877ecb84ff75ef0fab45bac5'
      end
    end

    describe '#size' do
      it 'returns size in bytes' do
        expect(part.size).to eq 3
      end
    end

    describe '#md5_match?' do
      it 'returns true when md5 matches' do
        expect(part.md5_match?).to be true
      end

      it 'returns false when md5 does not match' do
        allow(part).to receive(:read_md5).and_return('wrongmd5value')
        expect(part.md5_match?).to be false
      end
    end
  end
end
