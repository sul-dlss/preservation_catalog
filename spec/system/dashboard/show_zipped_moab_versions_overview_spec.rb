# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Show ZippedMoabVersions overview' do
  let(:zip_endpoint1) { create(:zip_endpoint) }
  let(:zip_endpoint2) { create(:zip_endpoint) }

  before do
    create_list(:zipped_moab_version, 1, zip_endpoint: zip_endpoint1, status: :ok)
    create_list(:zipped_moab_version, 2, zip_endpoint: zip_endpoint1, status: :failed)
    create_list(:zipped_moab_version, 3, zip_endpoint: zip_endpoint1, status: :created)
    create_list(:zipped_moab_version, 4, zip_endpoint: zip_endpoint1, status: :incomplete)
    create_list(:zipped_moab_version, 5, zip_endpoint: zip_endpoint2, status: :ok)
  end

  it 'shows the ZippedMoabVersions overview page' do
    visit dashboard_zipped_moab_versions_path

    expect(page).to have_css('h1', text: 'Replication of zip part files to cloud endpoints')

    within('table#zippedmoabversions-by-zipendpoint-table tbody') do
      row = page.all('tr').find { |r| r.has_css?('th', text: zip_endpoint1.endpoint_name) }
      within(row) do
        expect(page).to have_css('td:nth-of-type(1)', text: '10')
        expect(page).to have_css('td:nth-of-type(2)', text: '1')
        expect(page).to have_css('td:nth-of-type(3)', text: '2')
        expect(page).to have_css('td:nth-of-type(4)', text: '3')
        expect(page).to have_css('td:nth-of-type(5)', text: '4')
      end

      within('tr:last-of-type') do
        expect(page).to have_css('th', text: 'TOTAL')
        expect(page).to have_css('td:nth-of-type(1)', text: '15')
        expect(page).to have_css('td:nth-of-type(2)', text: '6')
        expect(page).to have_css('td:nth-of-type(3)', text: '2')
        expect(page).to have_css('td:nth-of-type(4)', text: '3')
        expect(page).to have_css('td:nth-of-type(5)', text: '4')
      end
    end
  end
end
