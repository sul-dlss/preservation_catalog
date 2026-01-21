# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Show dashboard overview' do
  before do
    allow(MoabRecord).to receive_messages(errors_count: 1, stuck_count: 2, validity_unknown_count: 5, expired_checksum_validation_with_grace_count: 9)
    allow(ZippedMoabVersion).to receive_messages(errors_count: 3, stuck_count: 4, created_count: 6, incomplete_count: 7, missing_count: 8)
    allow(PreservedObject).to receive(:expired_archive_audit_with_grace_count).and_return(10)
  end

  it 'shows the dashboard overview page' do
    visit dashboard_root_path
    expect(page).to have_css('h1', text: 'Preservation System Status Overview')

    within('table#status-errors-table tbody') do
      within('tr:nth-of-type(1)') do
        expect(page).to have_css('th', text: 'MoabRecords')
        expect(page).to have_css('td:nth-of-type(1)', text: '1')
        expect(page).to have_css('td:nth-of-type(2)', text: '2')
      end

      within('tr:nth-of-type(2)') do
        expect(page).to have_css('th', text: 'ZippedMoabVersions')
        expect(page).to have_css('td:nth-of-type(1)', text: '3')
        expect(page).to have_css('td:nth-of-type(2)', text: '4')
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
