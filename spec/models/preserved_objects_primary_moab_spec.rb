# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PreservedObjectsPrimaryMoab, type: :model do
  let(:cm) { create(:complete_moab) }
  let(:po) { cm.preserved_object }
  let(:alt_po) { create(:preserved_object) }

  it 'is valid when primary moab preserved objects agree' do
    expect(described_class.new(complete_moab: cm, preserved_object: po)).to be_valid
  end

  it 'raises error if complete moab preserved object differs from primary moab' do
    expect { described_class.create(complete_moab: cm, preserved_object: alt_po) }.to raise_error(RuntimeError, /does not match/)
  end
end
