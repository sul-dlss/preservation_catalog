# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::ObjectVersionsComponent, type: :component do
  let(:rendered) { render_inline(described_class.new) }
  let(:rendered_html) { rendered.to_html }

  it 'renders CompleteMoab Information' do
    expect(rendered).to match(/Counts and Version Information/)
    expect(rendered).to match(/object version count/) # table header
    expect(rendered_html).to match('<td class="text-end">0</td>') # table data
  end

  context 'when count mismatch' do
    let!(:preserved_object) { create(:preserved_object) } # rubocop:disable RSpec/LetSetup

    it 'renders count mismatches with danger styling' do
      expect(rendered_html).to match('<td class="text-end table-danger">1</td>') # preserved object count
      expect(rendered_html).to match('<td class="text-end table-danger">0</td>') # complete moab count
    end
  end
end
