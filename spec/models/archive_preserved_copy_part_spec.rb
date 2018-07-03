require 'rails_helper'

RSpec.describe ArchivePreservedCopyPart, type: :model do
  let(:apc) { create(:archive_preserved_copy) }
  let(:args) { attributes_for(:archive_preserved_copy_part).merge(archive_preserved_copy: apc) }

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
  it { is_expected.to validate_presence_of(:archive_preserved_copy) }
  it { is_expected.to belong_to(:archive_preserved_copy) }
end
