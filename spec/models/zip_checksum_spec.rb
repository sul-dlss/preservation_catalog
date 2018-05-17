require 'rails_helper'

RSpec.describe ZipChecksum, type: :model do
  let(:po) { create(:preserved_object) }
  let(:pres_copy) { create(:preserved_copy, preserved_object: po, endpoint: Endpoint.first) }
  let(:zip_checksum) do
    ZipChecksum.create(md5: '387a8ds87ea87', create_info: 'shell command and OS info', preserved_copy: pres_copy)
  end

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
  it { is_expected.to validate_presence_of(:md5) }
  it { is_expected.to validate_presence_of(:create_info) }
  it { is_expected.to validate_presence_of(:preserved_copy) }
  it { is_expected.to belong_to(:preserved_copy) }
end
