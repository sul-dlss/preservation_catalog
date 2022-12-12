# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Dashboard::ZipPartsSuffixesComponent, type: :component do
  let(:rendered) { render_inline(described_class.new) }
  let(:rendered_html) { rendered.to_html }

  it 'renders ZipPart suffix information' do
    expect(rendered).to match(/ZipPart/)
    expect(rendered).to match(/suffix/) # table header
    expect(rendered_html).to match(/\.zip/) # table data
    expect(rendered_html).to match(/10g/) # reference to Replication::DruidVersionZipPart::ZIP_PART_SIZE
  end
end
