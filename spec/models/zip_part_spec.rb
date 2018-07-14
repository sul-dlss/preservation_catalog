require 'rails_helper'

RSpec.describe ZipPart, type: :model do
  let(:apc) { create(:zipped_moab_version) }
  let(:args) { attributes_for(:zip_part).merge(zipped_moab_version: apc) }

  it 'defines a status enum with the expected values' do
    is_expected.to define_enum_for(:status).with(
      'ok' => 0,
      'unreplicated' => 1
    )
  end

  it 'is not valid unless it has all required attributes' do
    expect(described_class.new).not_to be_valid
    expect(described_class.new(args.merge(md5: nil))).not_to be_valid
    expect(described_class.new(args.merge(create_info: nil))).not_to be_valid
    expect(described_class.new(args)).to be_valid
  end

  context "md5 checksum validation" do
    it "enforces legnth of 32" do
      expect(described_class.new(args.merge(md5: "00236a2ae5580"))).not_to be_valid
      expect(described_class.new(args.merge(md5: "00236a2ae558018ed13b5222ef1bd977"))).to be_valid
    end
    it "enforces content contains only a-f and 0-9 characters" do
      expect(described_class.new(args.merge(md5: "ghijklmnopqrstuvwxyz123456789101"))).not_to be_valid
      expect(described_class.new(args.merge(md5: "abcdeabcdefabcdefabcdefabcdeff21"))).to be_valid
    end
  end

  it { is_expected.to validate_presence_of(:create_info) }
  it { is_expected.to validate_presence_of(:md5) }
  it { is_expected.to validate_presence_of(:parts_count) }
  it { is_expected.to validate_presence_of(:size) }
  it { is_expected.to validate_presence_of(:suffix) }
  it { is_expected.to validate_presence_of(:zipped_moab_version) }
  it { is_expected.to belong_to(:zipped_moab_version) }
end
