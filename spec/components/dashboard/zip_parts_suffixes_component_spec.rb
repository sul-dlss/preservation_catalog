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

  describe '#sorted_zip_parts_suffixes' do
    let(:unsorted) do
      {
        '.z01' => 12,
        '.z05' => 10,
        '.zip' => 25,
        '.z10' => 5,
        '.z100' => 1
      }
    end
    let(:class_instance) { described_class.new }

    before do
      # this is from Dashboard::ReplicationService
      allow(class_instance).to receive(:zip_part_suffixes).and_return(unsorted)
    end

    it 'returns .zip first and rest in numerical order' do
      expect(class_instance.sorted_zip_parts_suffixes).to eq(%w[.zip .z01 .z05 .z10 .z100])
    end
  end
end
