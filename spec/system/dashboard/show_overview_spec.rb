# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Show dashboard overview' do
  before do
    # 1 with errors
    create(:moab_record, status: 'invalid_checksum')
    # 2 stuck
    create_list(:moab_record, 2, status: 'validity_unknown', updated_at: 2.weeks.ago)
    # 3 additional not stuck
    create_list(:moab_record, 3, status: 'validity_unknown')
    # 9 expired checksum validations + grace
    create_list(:moab_record, 9, last_checksum_validation: Time.current - Settings.preservation_policy.fixity_ttl.seconds - 8.days)
    # 3 with errors
    create_list(:zipped_moab_version, 3, status: 'failed')
    # 4 stuck
    create_list(:zipped_moab_version, 4, status: 'incomplete', status_updated_at: 2.weeks.ago)
    # 6 created
    create_list(:zipped_moab_version, 6, status: 'created')
    # 3 additional incomplete
    create_list(:zipped_moab_version, 3, status: 'incomplete')
    allow(ZippedMoabVersion).to receive(:missing_count).and_return(8)
    allow(PreservedObject).to receive(:expired_archive_audit_with_grace_count).and_return(10)
  end

  it 'shows the dashboard overview page' do
    visit dashboard_root_path
    expect(page).to have_css('h1', text: 'Preservation System Status Overview')

    within('table#status-errors-table tbody') do
      within('tr:nth-of-type(1)') do
        expect(page).to have_css('th', text: 'MoabRecords')
        within('td:nth-of-type(1)') do
          expect(page).to have_link('1', href: with_errors_dashboard_moab_records_path)
        end
        within('td:nth-of-type(2)') do
          expect(page).to have_link('2', href: stuck_dashboard_moab_records_path)
        end
      end

      within('tr:nth-of-type(2)') do
        expect(page).to have_css('th', text: 'ZippedMoabVersions')
        within('td:nth-of-type(1)') do
          expect(page).to have_link('3', href: with_errors_dashboard_zipped_moab_versions_path)
        end
        within('td:nth-of-type(2)') do
          expect(page).to have_link('4', href: stuck_dashboard_zipped_moab_versions_path)
        end
      end
    end

    within('table#system-warnings-table tbody') do
      within('tr:nth-of-type(1)') do
        expect(page).to have_css('th', text: 'MoabRecord with validity_unknown status')
        expect(page).to have_css('td', text: '5')
      end

      within('tr:nth-of-type(2)') do
        expect(page).to have_css('th', text: 'ZippedMoabVersions with created status')
        expect(page).to have_css('td', text: '6')
      end

      within('tr:nth-of-type(3)') do
        expect(page).to have_css('th', text: 'ZippedMoabVersions with incomplete status')
        expect(page).to have_css('td', text: '7')
        expect(page).to have_link('7', href: incomplete_dashboard_zipped_moab_versions_path)
      end

      within('tr:nth-of-type(4)') do
        expect(page).to have_css('th', text: 'Missing ZippedMoabVersions')
        expect(page).to have_css('td', text: '8')
      end

      within('tr:nth-of-type(5)') do
        expect(page).to have_css('th', text: 'Expired MoabRecord checksum validations + 7 day grace')
        expect(page).to have_css('td', text: '9')
      end

      within('tr:nth-of-type(6)') do
        expect(page).to have_css('th', text: 'Expired PreservedObject replication audits + 7 day grace')
        expect(page).to have_css('td', text: '10')
      end
    end
  end
end
