# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Show stuck MoabRecords' do
  context 'when there are no stuck MoabRecords' do
    it 'reports no stuck MoabRecords' do
      visit stuck_dashboard_moab_records_path

      expect(page).to have_css('h1', text: 'Stuck MoabRecords')
      expect(page).to have_text('No records found.')
    end
  end

  context 'when there are stuck MoabRecords' do
    let(:preserved_object) { create(:preserved_object) }
    let!(:moab_record) do
      create(:moab_record,
             preserved_object: preserved_object,
             status: 'validity_unknown',
             updated_at: 3.weeks.ago)
    end

    before do
      create_list(:moab_record, 3, status: 'validity_unknown', updated_at: 2.weeks.ago)

      Kaminari.configure do |config|
        config.default_per_page = 3
      end
    end

    it 'lists the stuck MoabRecords' do
      visit stuck_dashboard_moab_records_path

      expect(page).to have_css('h1', text: 'Stuck MoabRecords')

      within('table#stuck-moab-records-table tbody') do
        expect(page).to have_css('tr', count: 3)

        within('tr:nth-of-type(1)') do
          expect(page).to have_css('th', text: moab_record.druid)
          expect(page).to have_link(moab_record.druid, href: dashboard_object_path(moab_record.druid))
        end
      end

      expect(page).to have_css('nav.pagination')
    end
  end
end
