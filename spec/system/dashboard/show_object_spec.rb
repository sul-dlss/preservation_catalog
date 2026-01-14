# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Show object show page' do
  let(:preserved_object) { create(:preserved_object) }
  let(:zip_endpoint) { create(:zip_endpoint) }

  context 'with a preserved object' do
    let(:s3_part_double) { double('s3_part', exists?: true, metadata: { 'checksum_md5' => 'dummy_md5' }) } # rubocop:disable RSpec/VerifiedDoubles

    before do
      create(:moab_record, preserved_object:)
    end

    context 'that is complete' do
      let(:zipped_moab_version) { create(:zipped_moab_version, preserved_object:, zip_endpoint:) }

      before do
        create_list(:zip_part, 2, zipped_moab_version:)
        allow_any_instance_of(ZipPart).to receive(:s3_part).and_return(s3_part_double) # rubocop:disable RSpec/AnyInstance
      end

      it 'shows the object show page without warnings' do
        visit dashboard_object_path(druid: preserved_object.druid)

        expect(page).to have_css('h1', text: "Preserved Object: druid:#{preserved_object.druid}")
        expect(page).to have_no_css('.alert')
        within('table#details-table tbody') do
          expect(page).to have_css('tr:nth-of-type(1) th', text: 'Druid')
          expect(page).to have_css('tr:nth-of-type(1) td', text: preserved_object.druid)
        end

        within('table#moab-record-table tbody') do
          expect(page).to have_css('tr:nth-of-type(1) th', text: 'Version')
          expect(page).to have_css('tr:nth-of-type(1) td', text: preserved_object.moab_record.version)
        end

        within("table#zipped-moab-version-table-#{zipped_moab_version.id} tbody") do
          expect(page).to have_css('tr:nth-of-type(1) th', text: 'Version')
          expect(page).to have_css('tr:nth-of-type(1) td', text: zipped_moab_version.version)
        end

        within("table#zip-part-table-#{zipped_moab_version.zip_parts.first.id} tbody") do
          expect(page).to have_css('tr:nth-of-type(1) th', text: 'Size')
          expect(page).to have_css('tr:nth-of-type(1) td', text: zipped_moab_version.zip_parts.first.size)
          expect(page).to have_css('tr:nth-of-type(2) th', text: 'Checksum')
          expect(page).to have_css('tr:nth-of-type(2) td', text: zipped_moab_version.zip_parts.first.md5)
        end
      end
    end

    context 'that is missing zip parts' do
      let!(:zipped_moab_version) { create(:zipped_moab_version, preserved_object:, zip_endpoint:) }

      it 'shows the object show page with a zip part alert' do
        visit dashboard_object_path(druid: preserved_object.druid)

        expect(page).to have_css('h1', text: "Preserved Object: druid:#{preserved_object.druid}")
        expect(page).to have_css('div.alert.alert-warning', text: "Zipped Moab Version #{zipped_moab_version.version} has no associated Zip Parts.")
      end
    end

    context 'that is missing zip moab versions' do
      it 'shows the object show page with a zip moab versions alert' do
        visit dashboard_object_path(druid: preserved_object.druid)

        expect(page).to have_css('h1', text: "Preserved Object: druid:#{preserved_object.druid}")
        expect(page).to have_css('div.alert.alert-danger', text: 'No Zipped Moab Versions found for this Preserved Object.')
      end
    end
  end

  context 'with a preserved object and no moab record' do
    it 'shows the object show page with a moab record alert' do
      visit dashboard_object_path(druid: preserved_object.druid)

      expect(page).to have_css('h1', text: "Preserved Object: druid:#{preserved_object.druid}")
      expect(page).to have_css('div.alert.alert-danger', text: 'No Moab Record found for this Preserved Object.')
    end
  end

  context 'with the preserved object is not found' do
    let(:druid) { 'aa11bb2222' }

    it 'shows the object show page with a moab record alert' do
      visit dashboard_object_path(druid: druid)

      expect(page).to have_css('h1', text: "Preserved Object: druid:#{druid}")
      expect(page).to have_css('div.alert.alert-danger', text: "No Preserved Object found with druid #{druid}.")
    end
  end
end
