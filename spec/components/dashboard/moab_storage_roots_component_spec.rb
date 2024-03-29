# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::MoabStorageRootsComponent, type: :component do
  let(:storage_root) { create(:moab_storage_root) }
  let(:rendered) { render_inline(described_class.new) }
  let(:rendered_html) { rendered.to_html }

  it 'renders MoabStorageRoot Information' do
    expect(rendered).to match(/MoabStorageRoot Information/)
    expect(rendered).to match(/storage location/) # table header
  end

  it 'renders MoabRecord statuses with blanks instead of underscores' do
    expect(rendered).to match(/moab on storage not found/)
  end

  describe 'storage root counts' do
    before do
      create(:moab_record, status: 'ok', moab_storage_root: storage_root)
      create(:moab_record, status: 'ok', moab_storage_root: storage_root, last_checksum_validation: 5.days.ago)
      create(:moab_record, status: 'moab_on_storage_not_found', moab_storage_root: storage_root)
      create(:moab_record, status: 'moab_on_storage_not_found', moab_storage_root: storage_root)
      create(:moab_record, status: 'moab_on_storage_not_found', moab_storage_root: storage_root)
      create(:moab_record, status: 'invalid_moab', moab_storage_root: storage_root, last_checksum_validation: 8.days.ago)
    end

    it 'renders MoabRecord counts' do
      expect(rendered_html).to match(%r{<td class="text-end">6</td>}) # count without table color class
      expect(rendered_html).to match(%r{<td class="text-end">2</td>}) # ok count per before block
      expect(rendered_html).to match(%r{<td class="text-end table-danger">1</td>}) # invalid_moab count per before block
      expect(rendered_html).to match(%r{<td class="text-end table-danger">3</td>}) # moab_on_storage_not_found count per before block
      # expired checksum audit count with warning styling
      expect(rendered.css('.table-warning').text).to match(/4/)
    end
  end
end
