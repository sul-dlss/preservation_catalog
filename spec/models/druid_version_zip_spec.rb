require 'rails_helper'

describe DruidVersionZip do
  subject(:dvz) { described_class.new(druid, version) }

  let(:druid) { 'bj102hs9687' }
  let(:version) { 1 }

  describe '#s3_key' do
    it 'returns a tree path-based key' do
      expect(dvz.s3_key).to eq 'bj/102/hs/9687/bj102hs9687.v0001.zip'
    end
  end

  describe '#file_path' do
    it 'returns a full path' do
      expect(dvz.file_path).to eq '/tmp/bj/102/hs/9687/bj102hs9687.v0001.zip'
    end
  end

  describe '#file' do
    it 'opens file_path' do
      expect(File).to receive(:open).with(dvz.file_path)
      dvz.file
    end
  end

  describe '#md5' do
    before do
      allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
    end
    it 'returns checksum' do
      expect(dvz.md5).to eq 'd41d8cd98f00b204e9800998ecf8427e'
    end
  end
end
