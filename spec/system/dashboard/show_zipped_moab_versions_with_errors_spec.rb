# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Show ZippedMoabVersions with errors' do
  context 'when there are no ZippedMoabVersions with errors' do
    it 'reports no records with errors' do
      visit with_errors_dashboard_zipped_moab_versions_path

      expect(page).to have_css('h1', text: 'ZippedMoabVersions in failed status')
      expect(page).to have_text('No records found.')
    end
  end

  context 'when there are ZippedMoabVersions with errors' do
    let(:preserved_object) { create(:preserved_object) }
    let!(:zipped_moab_version) do
      create(:zipped_moab_version,
             preserved_object: preserved_object,
             status: 'failed',
             status_details: 'Missing from cloud endpoint')
    end

    before do
      create_list(:zipped_moab_version, 3, status: 'failed')
      Kaminari.configure do |config|
        config.default_per_page = 3
      end
    end

    it 'lists the ZippedMoabVersions with errors' do
      visit with_errors_dashboard_zipped_moab_versions_path

      expect(page).to have_css('h1', text: 'ZippedMoabVersions in failed status')

      within('table#zipped-moab-versions-with-errors-table tbody') do
        expect(page).to have_css('tr', count: 3)

        within('tr:nth-of-type(1)') do
          expect(page).to have_css('th', text: zipped_moab_version.druid)
          expect(page).to have_link(zipped_moab_version.druid, href: dashboard_object_path(zipped_moab_version.druid))
          expect(page).to have_css('td:nth-of-type(1)', text: 'failed')
          expect(page).to have_css('td:nth-of-type(2)', text: 'Missing from cloud endpoint')
        end
      end

      expect(page).to have_css('nav.pagination')
    end
  end
end
