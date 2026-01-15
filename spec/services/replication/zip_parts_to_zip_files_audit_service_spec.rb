# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Replication::ZipPartsToZipFilesAuditService do
  subject(:results) { described_class.call(zipped_moab_version:) }

  let(:preserved_object) { create(:preserved_object_fixture, druid: 'bj102hs9687') }

  let(:zipped_moab_version) do
    create(:zipped_moab_version, preserved_object:)
  end

  let!(:zip_part) { create(:zip_part, zipped_moab_version:) }
  let!(:mismatched_zip_part) { create(:zip_part, zipped_moab_version:) }

  before do
    allow(zip_part.druid_version_zip_part).to receive(:read_md5).and_return(zip_part.md5)
    allow(mismatched_zip_part.druid_version_zip_part).to receive(:read_md5).and_return('different_md5_value')
  end

  it 'returns results for zip parts with md5 mismatches' do
    expect(results.size).to eq 1
    expect(results.to_s).to match(%r{bj/102/hs/9687/bj102hs9687\.v0001\.z.. catalog md5 \(00236a2ae558018ed13b5222ef1bd977\) doesn't match the local zip file md5 \(different_md5_value\)}) # rubocop:disable Layout/LineLength
  end
end
