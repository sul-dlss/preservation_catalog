# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Show MoabRecords overview' do
  let(:moab_storage_root1) { create(:moab_storage_root) }
  let(:moab_storage_root2) { create(:moab_storage_root) }

  before do
    create(:moab_record, moab_storage_root: moab_storage_root1, status: 'ok', size: 100, version: 66)
    create_list(:moab_record, 2, moab_storage_root: moab_storage_root1, status: 'invalid_moab', size: 101)
    create_list(:moab_record, 3, moab_storage_root: moab_storage_root1, status: 'invalid_checksum', size: 102)
    create_list(:moab_record, 4, moab_storage_root: moab_storage_root1, status: 'moab_on_storage_not_found', size: 103)
    create_list(:moab_record, 5, moab_storage_root: moab_storage_root1, status: 'unexpected_version_on_storage', size: 104)
    create_list(:moab_record, 6, moab_storage_root: moab_storage_root1, status: 'validity_unknown', size: 105)
    create_list(:moab_record, 7, moab_storage_root: moab_storage_root2, status: 'ok', size: 200)
  end

  it 'shows the MoabRecords overview page' do
    visit dashboard_moab_records_path

    expect(page).to have_css('h1', text: 'Files in Moabs on Local Storage')

    within('table#moabrecords-by-moabstorageroot-table tbody') do
      row = page.all('tr').find { |r| r.has_css?('th', text: moab_storage_root1.name) }
      within(row) do
        expect(page).to have_css('td:nth-of-type(1)', text: moab_storage_root1.storage_location)
        expect(page).to have_css('td:nth-of-type(2)', text: '2.12 KB')
        expect(page).to have_css('td:nth-of-type(3)', text: '21')
        expect(page).to have_css('td:nth-of-type(4)', text: '1')
        expect(page).to have_css('td:nth-of-type(5)', text: '2')
        expect(page).to have_css('td:nth-of-type(6)', text: '3')
        expect(page).to have_css('td:nth-of-type(7)', text: '4')
        expect(page).to have_css('td:nth-of-type(8)', text: '5')
        expect(page).to have_css('td:nth-of-type(9)', text: '6')
      end

      within('tr:last-of-type') do
        expect(page).to have_css('th', text: 'TOTAL')
        expect(page).to have_css('td:nth-of-type(1)', text: '3.49 KB')
        expect(page).to have_css('td:nth-of-type(2)', text: '28')
        expect(page).to have_css('td:nth-of-type(3)', text: '8')
        expect(page).to have_css('td:nth-of-type(4)', text: '2')
        expect(page).to have_css('td:nth-of-type(5)', text: '3')
        expect(page).to have_css('td:nth-of-type(6)', text: '4')
        expect(page).to have_css('td:nth-of-type(7)', text: '5')
        expect(page).to have_css('td:nth-of-type(8)', text: '6')
      end
    end

    within('table#versions-table tbody') do
      within('tr:nth-of-type(1)') do
        expect(page).to have_css('th', text: 'Max version')
        expect(page).to have_css('td', text: '66')
      end
    end
  end
end
