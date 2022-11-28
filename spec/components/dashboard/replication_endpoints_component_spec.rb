# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::ReplicationEndpointsComponent, type: :component do
  let(:rendered) { render_inline(described_class.new) }
  let(:rendered_html) { rendered.to_html }

  it 'renders Replication Endpoints information' do
    expect(rendered).to match(/Endpoint Data/)
    expect(rendered).to match(/endpoint name/) # table header
    expect(rendered_html).to match(/aws_s3_west_2/) # table data
  end

  context 'when count mismatch' do
    before do
      create(:preserved_object)
    end

    it 'renders replication count mismatches with danger styling' do
      expect(rendered_html).to match('<td class="text-end table-danger">0</td>') # ZippedMoabVersion replicated count
    end

    it 'renders PreservedObject count without danger styling' do
      expect(rendered_html).to match('<td class="text-end">1</td>') # PreservedObject version count
    end
  end
end
