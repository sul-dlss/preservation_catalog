# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::CompleteMoabsComponent, type: :component do
  let(:storage_root) { create(:moab_storage_root) }
  let(:rendered) { render_inline(described_class.new) }
  let(:rendered_html) { rendered.to_html }

  it 'renders CompleteMoab Information' do
    expect(rendered).to match(/CompleteMoab Information/)
    expect(rendered).to match(/average size/) # table header
    expect(rendered_html).to match('0 Bytes') # table data
  end

  it 'renders CompleteMoab statuses with blanks instead of underscores' do
    expect(rendered).to match(/online moab not found/)
  end

  describe 'CompleteMoab counts' do
    before do
      create(:complete_moab, status: 'ok', moab_storage_root: storage_root)
      create(:complete_moab, status: 'ok', moab_storage_root: storage_root, last_checksum_validation: 5.days.ago)
      create(:complete_moab, status: 'online_moab_not_found', moab_storage_root: storage_root)
      create(:complete_moab, status: 'online_moab_not_found', moab_storage_root: storage_root)
      create(:complete_moab, status: 'online_moab_not_found', moab_storage_root: storage_root)
      create(:complete_moab, status: 'invalid_moab', moab_storage_root: storage_root, last_checksum_validation: 8.days.ago)
    end

    it 'renders CompleteMoab counts' do
      expect(rendered_html).to match(%r{<td>6</td>}) # count without table color class
      expect(rendered_html).to match(%r{<td>2</td>}) # ok count per before block
      expect(rendered_html).to match(%r{<td class="table-danger">1</td>}) # invalid_moab count per before block
      expect(rendered_html).to match(%r{<td class="table-danger">3</td>}) # online_moab_not_found count per before block
      # expired checksum audit count with warning styling
      expect(rendered.css('.table-warning').text).to match(/4/)
    end
  end
end
