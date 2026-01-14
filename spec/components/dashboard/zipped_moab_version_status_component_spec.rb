# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::ZippedMoabVersionStatusComponent, type: :component do
  let(:rendered) { render_inline(described_class.new) }
  let(:rendered_html) { rendered.to_html }

  it 'renders ZippedMoabVersion Status information' do
    expect(rendered).to match(/ZippedMoabVersion Status/)
    expect(rendered).to match(/replication incomplete/) # table header
    expect(rendered_html).to match(/0/) # table data
  end

  it 'renders failed count with danger styling' do
    create(:zipped_moab_version, status: 'failed')
    expect(rendered_html).to match('<td class="text-end table-danger">1</td>')
  end

  it 'renders replication incomplete count with warning styling' do
    create(:zipped_moab_version, status: 'incomplete')
    expect(rendered_html).to match('<td class="text-end table-warning">1</td>')
  end
end
