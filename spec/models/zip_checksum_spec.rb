require 'rails_helper'

RSpec.describe ZipChecksum, type: :model do
  let(:po) { create(:preserved_object) }
  let(:pres_copy) { create(:preserved_copy, preserved_object: po, endpoint: Endpoint.first) }
  let(:zip_checksum) { create(:zip_checksum, preserved_copy: pres_copy) }

  it 'is not valid without valid attributes' do
    zc = ZipChecksum.new
    expect(zc).not_to be_valid
    expect { zc.save! }. to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'is not valid unless it has all required attributes' do
    zc = ZipChecksum.new(preserved_copy_id: pres_copy.id)
    expect(zc).not_to be_valid
    expect { zc.save! }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it 'is valid with valid attributes' do
    expect(zip_checksum).to be_valid
  end

  context "md5 checksum" do
    it "length is equal to 32" do
      zip_checksum = create(:zip_checksum, preserved_copy: pres_copy, md5: "00236a2ae558018ed13b5222ef1bd977")
      expect(zip_checksum).to be_valid
    end
    it "length is not equal to 32" do
      expect {
        create(:zip_checksum, preserved_copy: pres_copy, md5: "00236a2ae5580")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "contains only a-f and 0-9 characters" do
      zip_checksum = create(:zip_checksum, preserved_copy: pres_copy, md5: "abcdeabcdefabcdefabcdefabcdeff21")
      expect(zip_checksum).to be_valid
    end

    it "contains characters other than a-f" do
      expect {
        create(:zip_checksum, preserved_copy: pres_copy, md5: "ghijklmnopqrstuvwxyz123456789101")
      }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end
  it { is_expected.to validate_presence_of(:md5) }
  it { is_expected.to validate_presence_of(:create_info) }
  it { is_expected.to validate_presence_of(:preserved_copy) }
  it { is_expected.to belong_to(:preserved_copy) }
end
