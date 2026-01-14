# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ResultsReporters::HoneybadgerReporter do
  let(:druid) { 'ab123cd4567' }
  let(:actual_version) { 6 }
  let(:check_name) { 'FooCheck' }

  before do
    allow(Honeybadger).to receive(:notify)
  end

  describe '#report_errors' do
    context 'when handled error' do
      context 'when storage_area is a moab storage root' do
        let(:storage_area) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
        let(:result1) { { Results::MOAB_NOT_FOUND => 'db MoabRecord exists but Moab not found' } }
        let(:result2) { { Results::ZIP_PART_NOT_FOUND => 'replicated part not found' } }

        it 'notifies for each error' do
          described_class.new.report_errors(druid: druid,
                                            version: actual_version,
                                            storage_area:,
                                            check_name: check_name,
                                            results: [result1])
          expect(Honeybadger).to have_received(:notify).with(
            'FooCheck',
            context: {
              druid: "druid:#{druid}",
              storage_area: 'fixture_sr1',
              result: 'db MoabRecord exists but Moab not found'
            }
          ).once
        end
      end

      context 'when storage_area is a cloud endpoint' do
        let(:storage_area) { ZipEndpoint.find_by(endpoint_name: 'aws_s3_west_2') }
        let(:result1) { { Results::ZIP_PART_CHECKSUM_MISMATCH => 'local value for zip part checksum does not match cloud metadata' } }
        let(:result2) { { Results::ZIP_PART_NOT_FOUND => 'replicated part not found' } }

        it 'notifies for each error' do
          described_class.new.report_errors(druid: druid,
                                            version: actual_version,
                                            storage_area:,
                                            check_name: check_name,
                                            results: [result1, result2])
          expect(Honeybadger).to have_received(:notify).with(
            'FooCheck',
            context: {
              druid: "druid:#{druid}",
              storage_area: 'aws_s3_west_2',
              result: 'local value for zip part checksum does not match cloud metadata'
            }
          ).once
          expect(Honeybadger).to have_received(:notify).with(
            'FooCheck',
            context: {
              druid: "druid:#{druid}",
              storage_area: 'aws_s3_west_2',
              result: 'replicated part not found'
            }
          ).once
        end
      end
    end

    context 'when ignored error' do
      let(:storage_area) { ZipEndpoint.find_by(endpoint_name: 'aws_s3_west_2') }
      let(:result) { { Results::ZIP_PARTS_NOT_CREATED => 'no zip_parts exist yet for this ZippedMoabVersion' } }

      it 'does not notify' do
        described_class.new.report_errors(druid: druid, version: actual_version, storage_area:, check_name: check_name, results: [result])
        expect(Honeybadger).not_to have_received(:notify)
      end
    end
  end

  describe '#report_completed' do
    let(:storage_area) { MoabStorageRoot.find_by(storage_location: 'spec/fixtures/storage_root01/sdr2objects') }
    let(:result) { { Results::MOAB_RECORD_STATUS_CHANGED => 'MoabRecord status changed from invalid_moab' } }

    it 'does not notify' do
      described_class.new.report_completed(druid: druid, version: actual_version, storage_area:, check_name: check_name, result: result)
      expect(Honeybadger).not_to have_received(:notify)
    end
  end
end
