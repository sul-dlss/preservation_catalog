# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CardComponent, type: :component do
  let(:component) { described_class.new }

  it 'renders the component with provided content' do
    render_inline(component) do
      'This is card content'
    end

    expect(page).to have_css('div.card div.card-body', text: 'This is card content')
  end
end
