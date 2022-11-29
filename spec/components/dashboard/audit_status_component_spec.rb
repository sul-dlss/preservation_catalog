# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::AuditStatusComponent, type: :component do
  let(:rendered) { render_inline(described_class.new) }
  let(:rendered_html) { rendered.to_html }

  it 'renders Replication Status' do
    expect(rendered).to match(/Audit/) # top level status
    expect(rendered).to match(/Moab to Catalog/) # sub status
    expect(rendered).to match(/Catalog to Archive/) # sub status
    expect(rendered_html).to match('OK') # actual status data
    expect(rendered_html).to match(%r{<a href="resque">Redis queues</a>}) # link to redis
  end
end
