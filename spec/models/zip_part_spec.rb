# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ZipPart do
  let(:zmv) { build(:zipped_moab_version) }
  let(:args) { attributes_for(:zip_part, index: 1).merge(zipped_moab_version: zmv) }

  it 'is not valid unless it has all required attributes' do
    expect(described_class.new).not_to be_valid
    expect(described_class.new(args.merge(md5: nil))).not_to be_valid
    expect(described_class.new(args)).to be_valid
  end

  context 'md5 checksum validation' do
    it 'enforces legnth of 32' do
      expect(described_class.new(args.merge(md5: '00236a2ae5580'))).not_to be_valid
      expect(described_class.new(args.merge(md5: '00236a2ae558018ed13b5222ef1bd977'))).to be_valid
    end

    it 'enforces content contains only a-f and 0-9 characters' do
      expect(described_class.new(args.merge(md5: 'ghijklmnopqrstuvwxyz123456789101'))).not_to be_valid
      expect(described_class.new(args.merge(md5: 'abcdeabcdefabcdefabcdefabcdeff21'))).to be_valid
    end
  end

  context 'when creating a new ZipPart without unique zipped_moab_version_id/suffix combination' do
    before do
      described_class.create(args)
    end

    it 'raises ActiveRecord::RecordNotUnique' do
      expect { described_class.create(args) }.to raise_error(
        ActiveRecord::RecordNotUnique,
        /Key \(zipped_moab_version_id, suffix\)=\(#{zmv.id}, .zip\) already exist/
      )
    end
  end

  describe '#druid_version_zip' do
    let(:po) { build(:preserved_object, current_version: 3) }
    let(:zmv) { build(:zipped_moab_version, preserved_object: po, version: 1) }
    let(:zp) { described_class.new(args) }

    it 'gets a DruidVersionZip of the correct version' do
      expect(zp.druid_version_zip.version).to eq 1
    end
  end

  describe '#s3_key' do
    let(:po) { build(:preserved_object, current_version: 3) }
    let(:zmv) { build(:zipped_moab_version, preserved_object: po, version: 1) }
    let(:zp) { described_class.new(args) }

    it 'generates an s3_key with the correct version and suffix' do
      expect(zp.s3_key).to eq "#{DruidTools::Druid.new(po.druid).tree.join('/')}.v0001.zip"
    end
  end

  it { is_expected.to validate_presence_of(:md5) }
  it { is_expected.to validate_presence_of(:size) }
  it { is_expected.to validate_presence_of(:suffix) }
  it { is_expected.to belong_to(:zipped_moab_version) }
end
