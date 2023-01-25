# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::ReplicationEndpointStatusComponent, type: :component do
  let(:component) { described_class.new(endpoints: [endpoint_name, endpoint_info]) }
  let(:endpoint_name) { ZipEndpoint.first.endpoint_name }
  let(:endpoint_info) { { replication_count: 0 } }
  let(:rendered) { render_inline(component) }
  let(:rendered_html) { rendered.to_html }

  context 'when happy path' do
    it 'renders Replication Status with everything hunky-dory' do
      expect(rendered).to match(/Endpoint:/) # sub status
      expect(rendered_html).to match(Dashboard::ReplicationService::OK_LABEL) # actual status data
    end
  end

  context 'when count is not OK' do
    before do
      allow(component).to receive(:endpoint_replication_count_ok?).and_return(false)
    end

    it 'renders Replication Status with errors called out' do
      expect(rendered_html).to match(Dashboard::ReplicationService::NOT_OK_LABEL)
    end
  end
end
