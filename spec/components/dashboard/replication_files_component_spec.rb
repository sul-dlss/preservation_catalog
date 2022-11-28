# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::ReplicationFilesComponent, type: :component do
  let(:rendered) { render_inline(described_class.new) }
  let(:rendered_html) { rendered.to_html }

  it 'renders Replication Files information' do
    expect(rendered).to match(/Replication Files/)
    expect(rendered).to match(/unreplicated/) # table header
    expect(rendered_html).to match(/0 Bytes/) # table data
  end

  it 'renders ok status count with plain styling' do
    create(:zip_part, status: 'ok')
    expect(rendered_html).to match('<td class="text-end">1</td>')
  end

  it 'renders replicated_checksum_mismatch status count with danger styling' do
    create(:zip_part, status: 'replicated_checksum_mismatch')
    expect(rendered_html).to match('<td class="text-end table-danger">1</td>')
  end

  it 'renders unreplicated count with warning styling' do
    create(:zip_part, status: 'unreplicated')
    expect(rendered_html).to match('<td class="text-end table-warning">1</td>')
  end

  it 'renders not_found status count with danger styling' do
    create(:zip_part, status: 'not_found')
    expect(rendered_html).to match('<td class="text-end table-danger">1</td>')
  end
end
