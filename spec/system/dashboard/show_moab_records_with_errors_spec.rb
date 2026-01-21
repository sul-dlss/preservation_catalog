# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Show MoabRecords with errors' do
  context 'when there are no MoabRecords with errors' do
    it 'reports no records with errors' do
      visit with_errors_dashboard_moab_records_path

      expect(page).to have_css('h1', text: 'MoabRecords in error statuses')
      expect(page).to have_text('No records found.')
    end
  end

  context 'when there are MoabRecords with errors' do
    let(:preserved_object) { create(:preserved_object) }
    let!(:moab_record) do
      create(:moab_record,
             preserved_object: preserved_object,
             status: 'invalid_checksum',
             status_details: 'Checksum mismatch detected')
    end

    before do
      create_list(:moab_record, 3, status: 'invalid_moab')

      Kaminari.configure do |config|
        config.default_per_page = 3
      end
    end

    it 'lists the MoabRecords with errors' do
      visit with_errors_dashboard_moab_records_path

      expect(page).to have_css('h1', text: 'MoabRecords in error statuses')

      within('table#moab-records-with-errors-table tbody') do
        expect(page).to have_css('tr', count: 3)

        within('tr:nth-of-type(1)') do
          expect(page).to have_css('th', text: moab_record.druid)
          expect(page).to have_link(moab_record.druid, href: dashboard_object_path(moab_record.druid))
          expect(page).to have_css('td:nth-of-type(1)', text: 'invalid_checksum')
          expect(page).to have_css('td:nth-of-type(2)', text: 'Checksum mismatch detected')
        end
      end

      expect(page).to have_css('nav.pagination')
    end
  end
end
