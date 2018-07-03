require 'rails_helper'

describe DruidVersionZipPart do
  let(:dvz) { DruidVersionZip.new(druid, version) }
  let(:part) { described_class.new(dvz, 'bj/102/hs/9687/bj102hs9687.v0001.z02') }
  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }

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

  describe '#file' do
    it 'opens file_path' do
      expect(File).to receive(:open).with(part.file_path)
      part.file
    end
  end

  context 'MD5 checksums' do
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
      it 'returns base64-encoded value' do
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
  end
end
