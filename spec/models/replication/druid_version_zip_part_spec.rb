# frozen_string_literal: true

require 'rails_helper'

describe Replication::DruidVersionZipPart do
  let(:dvz) { Replication::DruidVersionZip.new(druid, version) }
  let(:part) { described_class.new(dvz, 'bj/102/hs/9687/bj102hs9687.v0001.z02') }
  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }
  let(:md5_path) { '/tmp/bj/102/hs/9687/bj102hs9687.v0001.z02.md5' }

  describe '#s3_key' do
    it 'returns a tree path-based key' do
      expect(part.s3_key).to eq 'bj/102/hs/9687/bj102hs9687.v0001.z02'
    end
  end

  describe '#file_path' do
    it 'returns a full path' do
      expect(part.file_path).to eq '/tmp/bj/102/hs/9687/bj102hs9687.v0001.z02'
    end
  end

  describe '#md5_path' do
    it 'returns the md5 path' do
      expect(part.md5_path).to eq md5_path
    end
  end

  describe '#write_md5' do
    let(:md5_path) { 'some/file/path/md5' }
    let(:md5) { 'fakemd5' }

    before do
      allow(part).to receive(:md5).and_return(md5)
      allow(part).to receive(:md5_path).and_return(md5_path)
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

  describe '#file' do
    it 'opens file_path' do
      expect(File).to receive(:open).with(part.file_path)
      part.file
    end
  end

  context 'MD5 checksums and size' do
    let(:part) { described_class.new(dvz, 'bj/102/hs/9687/bj102hs9687.v0001.zip') }

    before do
      allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
    end

    describe '#base64digest' do
      it 'returns base64-encoded value' do
        expect(part.base64digest).to eq 'T5j1nod+y4T/de8Pq0W6xQ=='
      end
    end

    describe '#hexdigest' do
      it 'returns hex-encoded value' do
        expect(part.hexdigest).to eq '4f98f59e877ecb84ff75ef0fab45bac5'
      end
    end

    describe '#hex_to_base64' do
      it 'returns base64-encoded value' do
        expect(part).not_to receive(:md5)
        expect(part.hex_to_base64('4f98f59e877ecb84ff75ef0fab45bac5')).to eq 'T5j1nod+y4T/de8Pq0W6xQ=='
        expect(part.hex_to_base64('d41d8cd98f00b204e9800998ecf8427e')).to eq '1B2M2Y8AsgTpgAmY7PhCfg=='
      end
    end

    describe '#md5' do
      it 'returns Digest::MD5 object' do
        expect(part.md5.to_s).to eq '4f98f59e877ecb84ff75ef0fab45bac5'
        expect(part.md5.to_s).to eq part.metadata[:checksum_md5]
      end
    end

    describe '#size' do
      it 'returns size in bytes' do
        expect(part.size).to eq 3
      end
    end
  end
end
