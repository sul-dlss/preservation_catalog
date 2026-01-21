# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Show stuck ZippedMoabVersions' do
  context 'when there are no stuck ZippedMoabVersions' do
    it 'reports no stuck ZippedMoabVersions' do
      visit stuck_dashboard_zipped_moab_versions_path

      expect(page).to have_css('h1', text: 'Stuck ZippedMoabVersions')
      expect(page).to have_text('No records found.')
    end
  end

  context 'when there are stuck ZippedMoabVersions' do
    let(:preserved_object) { create(:preserved_object) }
    let!(:zipped_moab_version) do
      create(:zipped_moab_version,
             preserved_object: preserved_object,
             status: 'incomplete',
             status_updated_at: 3.weeks.ago)
    end

    before do
      create_list(:zipped_moab_version, 3, status: 'created', status_updated_at: 2.weeks.ago)
      Kaminari.configure do |config|
        config.default_per_page = 3
      end
    end

    it 'lists the stuck ZippedMoabVersions' do
      visit stuck_dashboard_zipped_moab_versions_path

      expect(page).to have_css('h1', text: 'Stuck ZippedMoabVersions')

      within('table#stuck-zipped-moab-versions-table tbody') do
        expect(page).to have_css('tr', count: 3)

        within('tr:nth-of-type(1)') do
          expect(page).to have_css('th', text: zipped_moab_version.druid)
          expect(page).to have_link(zipped_moab_version.druid, href: dashboard_object_path(zipped_moab_version.druid))
          expect(page).to have_css('td:nth-of-type(1)', text: zipped_moab_version.version.to_s)
          expect(page).to have_css('td:nth-of-type(2)', text: zipped_moab_version.zip_endpoint.endpoint_name)
        end
      end

      expect(page).to have_css('nav.pagination')
    end
  end
end
