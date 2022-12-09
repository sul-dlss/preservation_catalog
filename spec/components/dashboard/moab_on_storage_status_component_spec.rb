# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::MoabOnStorageStatusComponent, type: :component do
  let(:rendered) { render_inline(described_class.new) }
  let(:rendered_html) { rendered.to_html }

  it 'renders Moabs on Storage Status' do
    expect(rendered).to match(/Moabs on Storage/) # top level status
    expect(rendered).to match(/MoabRecord Statuses/) # sub status
    expect(rendered_html).to match('OK') # actual status
  end
end
