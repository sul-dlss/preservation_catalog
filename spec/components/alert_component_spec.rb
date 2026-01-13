# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AlertComponent, type: :component do
  context 'when there are no notices' do
    it 'does not render alert content' do
      render_inline(described_class.new)
      expect(page).to have_no_css('.alert')
    end
  end

  context 'when there are notices' do
    before do
      allow(Settings).to receive(:notices).and_return([
                                                        ['warning', 'This is a test warning message.'],
                                                        ['info', 'This is a test info warning'],
                                                        ['alert', ''] # blank notices should not render
                                                      ])
    end

    it 'does renders a warning alert content' do
      render_inline(described_class.new)

      expect(page).to have_css('div.alert.alert-warning', text: 'This is a test warning message.')
      expect(page).to have_css('div.alert.alert-info', text: 'This is a test info warning')
      expect(page).to have_no_css('div.alert.alert-alert')
    end
  end
end
