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

  context 'MD5 checksums' do
    before do
      allow(Settings).to receive(:zip_storage).and_return(Rails.root.join('spec', 'fixtures', 'zip_storage'))
    end

    describe '#base64digest' do
      it 'returns base64-encoded value' do
        expect(dvz.base64digest).to eq 'T5j1nod+y4T/de8Pq0W6xQ=='
      end
    end

    describe '#hexdigest' do
      it 'returns base64-encoded value' do
        expect(dvz.hexdigest).to eq '4f98f59e877ecb84ff75ef0fab45bac5'
      end
    end

    describe '#hex_to_base64' do
      it 'returns base64-encoded value' do
        expect(dvz).not_to receive(:md5)
        expect(dvz.hex_to_base64('4f98f59e877ecb84ff75ef0fab45bac5')).to eq 'T5j1nod+y4T/de8Pq0W6xQ=='
        expect(dvz.hex_to_base64('d41d8cd98f00b204e9800998ecf8427e')).to eq '1B2M2Y8AsgTpgAmY7PhCfg=='
      end
    end
  end

  describe '#moab_version_path' do
    it 'returns authoritative file location' do
      expect(dvz.moab_version_path)
        .to eq 'spec/fixtures/storage_root01/moab_storage_trunk/bj/102/hs/9687/bj102hs9687/v0001'
    end
  end

  describe '#zip_command' do
    let(:moab_version_path) { Moab::StorageServices.object_version_path(druid, version) }
    let(:zip_path) { '/tmp/bj/102/hs/9687/bj102hs9687.v0001.zip' }

    it 'returns zip string to execute for this druid/version' do
      expect(dvz.zip_command).to eq "zip -vr0X -s 10g #{zip_path} #{moab_version_path}"
    end
  end

  describe '#zip_version' do
    it 'calls fetch_zip_version only once' do
      dvz.zip_version
      expect(dvz).not_to receive(:fetch_zip_version)
      dvz.zip_version
    end
  end

  describe '#zip_version_regexp' do
    subject { dvz.send(:zip_version_regexp) }

    it { is_expected.to match('This is Zip 3.0 (July 5th 2008), by Info-ZIP.') }
    it { is_expected.to match('This is Zip 5.0.2 (April 19th 2021), by Cyberdyne II') }
    it { is_expected.not_to match(%[Copyright (c) 1990-2008 Info-ZIP - Type 'zip "-L"' for software license.]) }
    it { is_expected.not_to match('bzip2, a block-sorting file compressor.  Version 1.0.6, 6-Sept-2010.') }
  end

  describe '#fetch_zip_version' do
    it 'gets version from the system zip' do
      expect(dvz.send(:fetch_zip_version)).to match(/^Zip \d+\.\d+/)
    end
  end
end
