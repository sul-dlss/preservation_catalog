# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreservedObjectsPrimaryMoab do
  let(:cm) { create(:complete_moab) }
  let(:po) { cm.preserved_object }
  let(:alt_po) { create(:preserved_object) }

  it 'is valid when primary moab preserved objects agree' do
    expect(described_class.new(complete_moab: cm, preserved_object: po)).to be_valid
  end

  it 'raises error if complete moab preserved object differs from primary moab' do
    bad_primary = described_class.create(complete_moab: cm, preserved_object: alt_po)
    expect(bad_primary).not_to be_valid
    expect(bad_primary.errors.messages[:preserved_object]).to eq ['must match the preserved object associated with the complete moab']
  end
end
