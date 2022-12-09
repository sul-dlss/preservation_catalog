# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::ReplicationFlowComponent, type: :component do
  let(:rendered) { render_inline(described_class.new) }
  let(:rendered_html) { rendered.to_html }

  it 'renders Replication Flow information' do
    expect(rendered).to match(/Replication Flow/)
    expect(rendered).to match(/ZipmakerJob/) # table text
  end

  it 'renders computed zip cache expiration in days' do
    expect(rendered_html).to match('14 days')
  end
end
