# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::ReplicationStatusComponent, type: :component do
  let(:component) { described_class.new }
  let(:rendered) { render_inline(component) }
  let(:rendered_html) { rendered.to_html }

  context 'when happy path' do
    it 'renders Replication Status with everything hunky-dory' do
      expect(rendered).to match(/Replication Zips/) # top level status
      expect(rendered).to match(/ZipPart Statuses/) # sub status
      expect(rendered).to match(/Endpoint:/) # sub status
      expect(rendered_html).to match(Dashboard::ReplicationService::OK_LABEL) # actual status data
      expect(rendered_html).to match(%r{<a href="queues">Redis queues</a>}) # link to redis
    end
  end

  context 'when replication & zip parts are not OK' do
    before do
      allow(component).to receive(:replication_and_zip_parts_ok?).and_return(false)
    end

    it 'renders Replication Status with errors called out' do
      expect(rendered_html).to match(Dashboard::ReplicationService::NOT_OK_LABEL)
    end
  end

  context 'when zip parts are not OK' do
    before do
      allow(component).to receive(:zip_parts_ok?).and_return(false)
    end

    it 'renders Replication Status with errors called out' do
      expect(rendered_html).to match(Dashboard::ReplicationService::NOT_OK_LABEL)
    end
  end
end
