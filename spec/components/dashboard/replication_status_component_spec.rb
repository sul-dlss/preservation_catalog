# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::ReplicationStatusComponent, type: :component do
  let(:rendered) { render_inline(described_class.new) }
  let(:rendered_html) { rendered.to_html }

  it 'renders Replication Status' do
    expect(rendered).to match(/Replication Zips/) # top level status
    expect(rendered).to match(/ZipPart Statuses/) # sub status
    expect(rendered).to match(/Endpoint:/) # sub status
    expect(rendered_html).to match('OK') # actual status data
    expect(rendered_html).to match(%r{<a href="queues">Redis queues</a>}) # link to redis
  end
end
